#!/usr/bin/env python3
"""Normalize a generated pet-state image to the runtime 512x512 RGBA contract.

Generated source may contain a white or rendered checkerboard background. This tool
uses edge colors plus GrabCut to recover foreground, keeps meaningful detached
pixels (water droplets), feathers the silhouette, and aligns it to a stable canvas.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

CANVAS = 512
MAX_EXTENT = 446
BASELINE = 479


def recover_alpha(bgr: np.ndarray) -> np.ndarray:
    height, width = bgr.shape[:2]
    # Generated checkerboards use a tiny palette sampled reliably at the border.
    border = np.concatenate((bgr[0], bgr[-1], bgr[:, 0], bgr[:, -1]))
    quantized = (border // 8) * 8
    colors, counts = np.unique(quantized.reshape(-1, 3), axis=0, return_counts=True)
    palette = colors[np.argsort(counts)[-6:]]
    distance = np.min(
        np.linalg.norm(bgr[:, :, None].astype(np.int16) - palette[None, None].astype(np.int16), axis=3),
        axis=2,
    )

    mask = np.full((height, width), cv2.GC_PR_FGD, np.uint8)
    mask[distance < 11] = cv2.GC_BGD
    mask[distance < 25] = cv2.GC_PR_BGD
    margin = max(4, min(height, width) // 100)
    mask[:margin] = cv2.GC_BGD
    mask[-margin:] = cv2.GC_BGD
    mask[:, :margin] = cv2.GC_BGD
    mask[:, -margin:] = cv2.GC_BGD

    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    yy, xx = np.ogrid[:height, :width]
    central = (xx > width * 0.12) & (xx < width * 0.88) & (yy > height * 0.08) & (yy < height * 0.95)
    confident_pet = central & ((hsv[:, :, 1] > 80) | (hsv[:, :, 2] < 105)) & (distance > 35)
    mask[confident_pet] = cv2.GC_FGD

    cv2.grabCut(bgr, mask, None, np.zeros((1, 65), np.float64), np.zeros((1, 65), np.float64), 6, cv2.GC_INIT_WITH_MASK)
    alpha = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 255, 0).astype(np.uint8)

    # Discard remote generation debris while preserving nearby droplets/hairs.
    count, labels, stats, _ = cv2.connectedComponentsWithStats(alpha, 8)
    if count > 1:
        largest = 1 + int(np.argmax(stats[1:, cv2.CC_STAT_AREA]))
        x, y, w, h = stats[largest, :4]
        keep = labels == largest
        pet_box = (x - w * 0.12, y - h * 0.12, x + w * 1.12, y + h * 1.12)
        for index in range(1, count):
            if index == largest or stats[index, cv2.CC_STAT_AREA] < 12:
                continue
            cx = stats[index, cv2.CC_STAT_LEFT] + stats[index, cv2.CC_STAT_WIDTH] / 2
            cy = stats[index, cv2.CC_STAT_TOP] + stats[index, cv2.CC_STAT_HEIGHT] / 2
            if pet_box[0] <= cx <= pet_box[2] and pet_box[1] <= cy <= pet_box[3]:
                keep |= labels == index
        alpha = np.where(keep, 255, 0).astype(np.uint8)

    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)
    alpha[alpha < 8] = 0
    return alpha


def normalize(source: Path, destination: Path) -> None:
    bgr = cv2.imread(str(source), cv2.IMREAD_COLOR)
    if bgr is None:
        raise ValueError(f"Cannot read {source}")
    alpha = recover_alpha(bgr)
    points = cv2.findNonZero((alpha > 8).astype(np.uint8))
    if points is None:
        raise ValueError(f"No foreground recovered from {source}")
    x, y, width, height = cv2.boundingRect(points)
    scale = MAX_EXTENT / max(width, height)
    new_width, new_height = max(1, round(width * scale)), max(1, round(height * scale))
    color_crop = bgr[y : y + height, x : x + width]
    alpha_crop = alpha[y : y + height, x : x + width]
    color = cv2.resize(color_crop, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)
    resized_alpha = cv2.resize(alpha_crop, (new_width, new_height), interpolation=cv2.INTER_LANCZOS4)

    rgba = cv2.cvtColor(color, cv2.COLOR_BGR2BGRA)
    rgba[:, :, 3] = resized_alpha
    canvas = np.zeros((CANVAS, CANVAS, 4), np.uint8)
    left = (CANVAS - new_width) // 2
    top = min(BASELINE - new_height, (CANVAS - new_height) // 2)
    canvas[top : top + new_height, left : left + new_width] = rgba
    destination.parent.mkdir(parents=True, exist_ok=True)
    if not cv2.imwrite(str(destination), canvas):
        raise OSError(f"Cannot write {destination}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("sources", nargs="+", type=Path)
    parser.add_argument("--output-dir", type=Path)
    args = parser.parse_args()
    for source in args.sources:
        destination = (args.output_dir / source.name) if args.output_dir else source
        normalize(source, destination)
        print(destination)


if __name__ == "__main__":
    main()

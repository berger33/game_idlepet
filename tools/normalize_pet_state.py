#!/usr/bin/env python3
"""Normalize a generated pet-state image to the runtime 512x512 RGBA contract.

Generated sources arrive either opaque (white/gray gradient or rendered
checkerboard backdrops) or with native transparency. Two foreground recovery
strategies are provided:

* grabcut (default): edge palette seeding plus GrabCut. Proven on colored
  coats over checkerboard/gradient backdrops across the catalogue.
* flood (--flood): floods the backdrop from the border over background-like
  pixels; the bold sticker outline stops the flood. Required when a light pet
  (white/cream coat) sits on a light backdrop, where GrabCut mistakes fur for
  backdrop and leaves holes.

Both paths keep meaningful detached pixels (water droplets), discard remote
debris, feather the silhouette and align it to a stable canvas.
"""
from __future__ import annotations

import argparse
from pathlib import Path

import cv2
import numpy as np

CANVAS = 512
MAX_EXTENT = 446
BASELINE = 479


def border_palette(bgr: np.ndarray) -> np.ndarray:
    border = np.concatenate((bgr[0], bgr[-1], bgr[:, 0], bgr[:, -1]))
    quantized = (border // 8) * 8
    colors, counts = np.unique(quantized.reshape(-1, 3), axis=0, return_counts=True)
    return colors[np.argsort(counts)[-6:]]


def distance_to_palette(bgr: np.ndarray, palette: np.ndarray) -> np.ndarray:
    return np.min(
        np.linalg.norm(bgr[:, :, None].astype(np.int16) - palette[None, None].astype(np.int16), axis=3),
        axis=2,
    )


def cleanup_and_feather(alpha: np.ndarray) -> np.ndarray:
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


def recover_alpha_grabcut(bgr: np.ndarray) -> np.ndarray:
    height, width = bgr.shape[:2]
    palette = border_palette(bgr)
    distance = distance_to_palette(bgr, palette)

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
    return cleanup_and_feather(alpha)


def recover_alpha_flood(bgr: np.ndarray) -> np.ndarray:
    height, width = bgr.shape[:2]
    palette = border_palette(bgr)
    distance = distance_to_palette(bgr, palette)

    # Flood the backdrop from the border over background-like pixels; the bold
    # sticker outline stops the flood, so white fur on a light backdrop stays
    # foreground even when fur and backdrop share light tones.
    bglike = distance < 25
    _, labels_bg, _, _ = cv2.connectedComponentsWithStats(bglike.astype(np.uint8), 8)
    border_ids = set(labels_bg[0, :]) | set(labels_bg[-1, :]) | set(labels_bg[:, 0]) | set(labels_bg[:, -1])
    background = np.isin(labels_bg, sorted(border_ids - {0}))
    alpha = np.where(background, 0, 255).astype(np.uint8)

    # Drop generation extras that are not the pet: a soft ground shadow hugging
    # the bottom, enclosed backdrop pockets (e.g. the tail/body loop) and sparse
    # backdrop debris such as checkerboard fragments or dashes.
    hsv = cv2.cvtColor(bgr, cv2.COLOR_BGR2HSV)
    value = bgr.max(axis=2).astype(np.float64)
    n2, labels2, stats2, centroids2 = cv2.connectedComponentsWithStats((alpha > 0).astype(np.uint8), 8)
    border_ids2 = set(labels2[0, :]) | set(labels2[-1, :]) | set(labels2[:, 0]) | set(labels2[:, -1])
    drop = np.zeros_like(alpha)
    for index in range(1, n2):
        component = labels2 == index
        comp_mask = component.astype(np.uint8)
        mean_v = float(cv2.mean(value, mask=comp_mask)[0])
        mean_s = float(cv2.mean(hsv[:, :, 1], mask=comp_mask)[0])
        bg_fraction = float(bglike[component].mean())
        centroid_y = float(centroids2[index][1])
        area = stats2[index, cv2.CC_STAT_AREA]
        bbox = stats2[index, cv2.CC_STAT_WIDTH] * stats2[index, cv2.CC_STAT_HEIGHT]
        fill = area / float(bbox) if bbox else 0.0
        ground_shadow = mean_v < 180 and mean_s < 50 and centroid_y > height * 0.75
        enclosed_pocket = bg_fraction > 0.9 and mean_v < 235
        backdrop_debris = (index in border_ids2 and fill < 0.25) or (area < 400 and mean_s < 50 and mean_v < 235)
        if ground_shadow or enclosed_pocket or backdrop_debris:
            drop[component] = 255
    alpha[drop > 0] = 0
    return cleanup_and_feather(alpha)


def native_alpha(rgba: np.ndarray) -> np.ndarray | None:
    """Reuse the source alpha when the generation already ships real transparency.

    When the model delivers a transparent PNG, recomputing the mask can mistake
    white fur for background. Native alpha with transparent corners is
    authoritative instead.
    """
    if rgba.ndim != 3 or rgba.shape[2] != 4:
        return None
    alpha = rgba[:, :, 3]
    if max(int(alpha[0, 0]), int(alpha[0, -1]), int(alpha[-1, 0]), int(alpha[-1, -1])) != 0:
        return None
    if (alpha > 8).mean() <= 0.03:
        return None
    alpha = cv2.GaussianBlur(alpha, (0, 0), 0.8)
    alpha[alpha < 8] = 0
    return alpha


def normalize(source: Path, destination: Path, flood: bool = False) -> None:
    raw = cv2.imread(str(source), cv2.IMREAD_UNCHANGED)
    if raw is None:
        raise ValueError(f"Cannot read {source}")
    bgr = raw[:, :, :3]
    alpha = native_alpha(raw)
    if alpha is None:
        alpha = recover_alpha_flood(bgr) if flood else recover_alpha_grabcut(bgr)
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
    parser.add_argument("--flood", action="store_true",
                        help="flood-fill backdrop recovery for light pets on light backdrops")
    args = parser.parse_args()
    for source in args.sources:
        destination = (args.output_dir / source.name) if args.output_dir else source
        normalize(source, destination, flood=args.flood)
        print(destination)


if __name__ == "__main__":
    main()

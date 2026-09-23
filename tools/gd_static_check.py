#!/usr/bin/env python3
"""Checagens estáticas leves de GDScript (Godot 4) que o gdlint não cobre.

Sem o binário do Godot disponível, este script pega as classes de erro de
parse mais comuns que só apareciam no job "runtime" da CI:

1. Redeclaração de variável local em escopo aninhado da MESMA função
   (``var x`` dentro de um ``if`` quando ``x`` já existe fora) — no Godot 4 é
   erro de parse ("There is already a variable named ... in this scope").
2. ``ClassName.has_method(...)`` / ``has_signal`` em classes ``class_name``
   (RefCounted estático) — "Cannot call non-static function ... directly".
3. Chamada de função local com menos argumentos que o mínimo exigido.

Uso: python3 tools/gd_static_check.py [arquivos.gd ...]  (padrão: repo todo)
Saída: lista de achados e código de saída 1 se houver algum.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
FUNC_RE = re.compile(r"^(\s*)(?:static\s+)?func\s+([A-Za-z_]\w*)\s*\((.*)$")
VAR_RE = re.compile(r"^\s*var\s+([A-Za-z_]\w*)\b")
FOR_RE = re.compile(r"^\s*for\s+([A-Za-z_]\w*)\b")
LAMBDA_RE = re.compile(r"\bfunc\s*\(")
CLASS_NAME_RE = re.compile(r"^class_name\s+([A-Za-z_]\w*)")


def indent_of(line: str) -> int:
    count = 0
    for ch in line:
        if ch == "\t":
            count += 4
        elif ch == " ":
            count += 1
        else:
            break
    return count


def strip_strings_and_comments(line: str) -> str:
    out: list[str] = []
    quote: str | None = None
    i = 0
    while i < len(line):
        ch = line[i]
        if quote:
            if ch == "\\":
                i += 2
                continue
            if ch == quote:
                quote = None
            i += 1
            continue
        if ch in ('"', "'"):
            quote = ch
            out.append('"')
            i += 1
            continue
        if ch == "#":
            break
        out.append(ch)
        i += 1
    return "".join(out)


def parse_params(signature: str) -> tuple[int, int, bool]:
    """Retorna (mínimo, máximo, variádico?) de parâmetros a partir do texto após 'func nome('."""
    depth = 1
    buf = ""
    params: list[str] = []
    for ch in signature:
        if ch in "([{":
            depth += 1
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                break
        if ch == "," and depth == 1:
            params.append(buf)
            buf = ""
            continue
        buf += ch
    if depth != 0:
        return (0, 99, True)  # assinatura multi-linha: não arriscar falso positivo
    if buf.strip():
        params.append(buf)
    params = [p.strip() for p in params if p.strip()]
    required = sum(1 for p in params if "=" not in p)
    return (required, len(params), False)


def count_call_args(text: str, open_idx: int) -> int | None:
    depth = 0
    args = 0
    has_content = False
    i = open_idx
    while i < len(text):
        ch = text[i]
        if ch in "([{":
            depth += 1
            if depth == 1:
                i += 1
                continue
        elif ch in ")]}":
            depth -= 1
            if depth == 0:
                return args + (1 if has_content else 0)
        if depth == 1:
            if ch == ",":
                args += 1
                has_content = False
            elif not ch.isspace():
                has_content = True
        i += 1
    return None  # chamada continua em outra linha: ignora


def check_file(path: Path, class_names: set[str], autoloads: set[str]) -> list[str]:
    findings: list[str] = []
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    static_classes = class_names - autoloads
    # --- assinatura das funções do arquivo (para checar aridade) ---
    signatures: dict[str, tuple[int, int, bool]] = {}
    for line in lines:
        m = FUNC_RE.match(line)
        if m:
            signatures[m.group(2)] = parse_params(m.group(3))
    # --- caminhada por função ---
    scope_stack: list[tuple[int, set[str]]] = []  # (indent, nomes declarados neste bloco)
    in_func = False
    func_indent = 0
    lambda_depth_indents: list[int] = []
    for number, raw in enumerate(lines, start=1):
        code = strip_strings_and_comments(raw)
        if not code.strip():
            continue
        ind = indent_of(raw)
        m = FUNC_RE.match(code)
        if m and not code.strip().startswith("var ") and "func(" not in code.split("func ")[0]:
            in_func = True
            func_indent = ind
            scope_stack = [(ind, set())]
            lambda_depth_indents = []
            # parâmetros contam como locais do bloco da função
            _, _, _ = parse_params(m.group(3))
            params_text = m.group(3).split(")")[0]
            for p in params_text.split(","):
                name = p.strip().split(":")[0].split("=")[0].strip()
                if name and re.fullmatch(r"[A-Za-z_]\w*", name):
                    scope_stack[0][1].add(name)
            continue
        if not in_func:
            continue
        if ind <= func_indent and not code.strip().startswith((")", "]", "}")):
            in_func = False
            scope_stack = []
            continue
        # lambdas abrem um novo "corpo de função": variáveis dentro delas podem repetir nomes externos
        if LAMBDA_RE.search(code):
            lambda_depth_indents.append(ind)
        # fecha blocos com indentação maior ou igual à atual (novo bloco irmão)
        while len(scope_stack) > 1 and scope_stack[-1][0] >= ind:
            scope_stack.pop()
        while lambda_depth_indents and lambda_depth_indents[-1] >= ind and not LAMBDA_RE.search(code):
            lambda_depth_indents.pop()
        # 2) has_method em classe estática
        for cls in static_classes:
            if re.search(rf"\b{cls}\.(has_method|has_signal|get_method_list)\(", code):
                findings.append(f"{path.relative_to(ROOT)}:{number}: '{cls}.has_method()' em class_name estática (Parse Error no Godot 4)")
        # 3) aridade em chamadas locais (só nomes com _ inicial: métodos privados do próprio arquivo)
        for call in re.finditer(r"(?<![\w.])(_[A-Za-z]\w*)\s*\(", code):
            name = call.group(1)
            if name not in signatures:
                continue
            if code.strip().startswith(("func ", "static func ")):
                continue
            required, maximum, variadic = signatures[name]
            if variadic:
                continue
            got = count_call_args(code, call.end() - 1)
            if got is None:
                continue
            if got < required:
                findings.append(f"{path.relative_to(ROOT)}:{number}: chamada '{name}()' com {got} arg(s); mínimo {required}")
        # 1) shadowing de local
        decl = VAR_RE.match(code) or FOR_RE.match(code)
        if decl:
            name = decl.group(1)
            inside_lambda = bool(lambda_depth_indents) and ind > lambda_depth_indents[-1]
            if not inside_lambda:
                for _, names in scope_stack:
                    if name in names:
                        findings.append(f"{path.relative_to(ROOT)}:{number}: variável local '{name}' redeclarada em escopo aninhado da mesma função (Parse Error no Godot 4)")
                        break
            # 'for x' declara x no corpo do laço (bloco filho); 'var x' no bloco atual
            if FOR_RE.match(code):
                scope_stack.append((ind, {name}))
                # marca para que o próximo nível mais indentado herde este bloco
                continue
            scope_stack[-1][1].add(name)
        # abre bloco filho para linhas terminadas em ':' (if/elif/else/for/while/match)
        if code.rstrip().endswith(":") and not decl:
            scope_stack.append((ind, set()))
    return findings


def main(argv: list[str]) -> int:
    files = [Path(a) for a in argv[1:]] if len(argv) > 1 else sorted(ROOT.rglob("*.gd"))
    files = [f for f in files if ".git" not in f.parts]
    class_names: set[str] = set()
    for f in files:
        for line in f.read_text(encoding="utf-8", errors="replace").splitlines():
            m = CLASS_NAME_RE.match(line)
            if m:
                class_names.add(m.group(1))
    autoloads: set[str] = set()
    project = ROOT / "project.godot"
    if project.exists():
        for line in project.read_text(encoding="utf-8").splitlines():
            m = re.match(r"^([A-Za-z_]\w*)=\"\*res://", line)
            if m:
                autoloads.add(m.group(1))
    findings: list[str] = []
    for f in files:
        findings.extend(check_file(f, class_names, autoloads))
    for item in findings:
        print("GD-CHECK:", item)
    print(f"gd_static_check: {len(files)} arquivos, {len(findings)} achado(s)")
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))

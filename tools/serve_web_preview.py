#!/usr/bin/env python3
"""Serve estático do build Web (exports/web) para playtest local/preview.

Sem dependências externas. Sobe em 0.0.0.0 para funcionar atrás de proxies de
preview e ajusta o MIME de .wasm/.pck (o Godot faz streaming do WASM e o fetch
do .pck falha se o servidor devolver text/plain).

Uso:
    godot --headless --path . --export-release "Web Preview" exports/web/index.html
    python3 tools/serve_web_preview.py [porta] [diretório]

O preset "Web Preview" usa variant/thread_support=false, então não precisa de
COOP/COEP (SharedArrayBuffer) e roda em hospedagem estática simples.
"""

import http.server
import os
import socketserver
import sys

DEFAULT_DIR = os.path.join(
	os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "exports", "web"
)
DEFAULT_PORT = 8060

TYPES = {
	".html": "text/html; charset=utf-8",
	".js": "application/javascript",
	".wasm": "application/wasm",
	".pck": "application/octet-stream",
	".png": "image/png",
	".json": "application/json",
	".svg": "image/svg+xml",
	".ico": "image/x-icon",
}


class Handler(http.server.SimpleHTTPRequestHandler):
	def __init__(self, *args, root: str = DEFAULT_DIR, **kwargs) -> None:
		super().__init__(*args, directory=root, **kwargs)

	def end_headers(self) -> None:
		# Build muda a cada export: sem cache o navegador não fica com .pck velho.
		self.send_header("Cache-Control", "no-store, must-revalidate")
		self.send_header("Access-Control-Allow-Origin", "*")
		super().end_headers()

	def guess_type(self, path: str) -> str:
		ext = os.path.splitext(path)[1].lower()
		return TYPES.get(ext, super().guess_type(path))


class Server(socketserver.ThreadingTCPServer):
	allow_reuse_address = True
	daemon_threads = True


def main() -> int:
	port = int(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_PORT
	root = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_DIR
	if not os.path.isfile(os.path.join(root, "index.html")):
		print("index.html não encontrado em %s — exporte o preset 'Web Preview' antes." % root)
		return 1
	with Server(("0.0.0.0", port), lambda *a, **kw: Handler(*a, root=root, **kw)) as httpd:
		print("servindo %s em 0.0.0.0:%d" % (root, port), flush=True)
		httpd.serve_forever()
	return 0


if __name__ == "__main__":
	raise SystemExit(main())

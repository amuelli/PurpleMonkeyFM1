#!/bin/sh
# SPDX-License-Identifier: GPL-3.0-only
# Try the working tree's firmware in the browser: build the browser emulator when a source is newer than the last
# build, then serve it on localhost.
#   sh tools/emu/web/serve_pm.sh [PORT]          (default 8791; the next free port when it is taken)
# Open the address it prints. localhost is a secure context, so the page's AudioWorklet (the sound) works there; a
# plain http://LAN-ADDRESS:PORT does not get audio, so keep the server on localhost and reach it from the browser
# that runs on this machine (the in-app browser's localhost is the machine the agent runs on) or through
# ssh -L PORT:localhost:PORT HOST. Ctrl-C stops it. Needs emcc for the build (build_pm_web.sh: PATH, $EMSDK or
# ~/emsdk; sh tools/linux/setup.sh --emscripten installs it); without emcc an existing build/emu-web-pm is served.
set -e
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
cd "$ROOT"
OUT=build/emu-web-pm
PORT=${1:-${PM_WEB_PORT:-8791}}

if [ ! -f "$OUT/purplemonkey.wasm" ] || \
   [ -n "$(find firmware/src tools/emu tools/gen*.py tools/gen.sh assets/purplemonkey -type f ! -name 'serve_pm.sh' ! -name 'test_*' -newer "$OUT/purplemonkey.wasm" 2>/dev/null | head -1)" ]; then
    echo "serve_pm: building the browser emulator"
    sh tools/emu/web/build_pm_web.sh
elif [ -z "${PM_WEB_QUIET:-}" ]; then
    echo "serve_pm: $OUT is up to date"
fi

exec python3 - "$OUT" "$PORT" <<'PY'
import functools, http.server, socket, sys

root, port = sys.argv[1], int(sys.argv[2])


class Handler(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        if not args[0].startswith("GET /favicon"):
            super().log_message(fmt, *args)


def free(p):
    with socket.socket() as s:
        return s.connect_ex(("127.0.0.1", p)) != 0


for p in range(port, port + 20):
    if free(p):
        break
else:
    sys.exit(f"serve_pm: no free port in {port}..{port + 19}")
if p != port:
    print(f"serve_pm: port {port} is taken, using {p}")
srv = http.server.ThreadingHTTPServer(("127.0.0.1", p), functools.partial(Handler, directory=root))
print(f"serve_pm: PurpleMonkey in the browser: http://localhost:{p}/   (Ctrl-C to stop)", flush=True)
try:
    srv.serve_forever()
except KeyboardInterrupt:
    pass
PY

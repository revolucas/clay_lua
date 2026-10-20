#!/usr/bin/env bash
set -euo pipefail

WEB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -f "$WEB_DIR/dist/index.html" ]]; then
	printf 'No web build found. Run make web first.\n' >&2
	exit 1
fi

PORT="${PORT:-8000}"
exec python3 -m http.server "$PORT" --directory "$WEB_DIR/dist"

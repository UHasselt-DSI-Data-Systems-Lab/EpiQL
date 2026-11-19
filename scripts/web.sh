#!/usr/bin/env bash
# Start the EpiQL web interface with this repository's models, tutorial and datasets,
# then open http://127.0.0.1:8780/ (or the --addr you pass). Stop it with Ctrl+C.
#
#   scripts/web.sh
#   scripts/web.sh --addr 127.0.0.1:9000     # any other epiql-web options are passed on
#
# Your own models and experiments are stored in epiql-workspace/.
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ ! -x ./epiql-web ]]; then
    echo "error: ./epiql-web not found; run scripts/setup.sh first" >&2
    exit 1
fi

exec ./epiql-web --models models --tutorial tutorial --data data --workspace epiql-workspace "$@"

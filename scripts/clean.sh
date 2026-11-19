#!/usr/bin/env bash
# Remove what the other scripts create: simulation results (runs/, output/) and the
# unpacked binaries. Your web interface workspace (epiql-workspace/) is kept unless
# you pass --all.
#
#   scripts/clean.sh
#   scripts/clean.sh --all
set -euo pipefail
cd "$(dirname "$0")/.."

remove=(runs output epiql epiql-web)
if [[ "${1:-}" == "--all" ]]; then
    remove+=(epiql-workspace)
fi
for path in "${remove[@]}"; do
    if [[ -e "$path" ]]; then
        rm -rf -- "$path"
        echo "removed $path"
    fi
done

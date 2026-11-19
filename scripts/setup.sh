#!/usr/bin/env bash
# Unpack the EpiQL binaries (epiql, epiql-web) into the repository root and check that
# this system can run them.
#
#   scripts/setup.sh                      # uses the newest epiql-*.tar.gz in the repository root
#   scripts/setup.sh path/to/archive.tar.gz
set -euo pipefail
cd "$(dirname "$0")/.."

archive="${1:-}"
if [[ -z "$archive" ]]; then
    archive="$(ls -t epiql-*-x86_64-linux.tar.gz 2>/dev/null | head -n1 || true)"
fi
if [[ -z "$archive" || ! -f "$archive" ]]; then
    echo "error: no release archive found" >&2
    echo "download epiql-<version>-x86_64-linux.tar.gz from the Releases page into $(pwd)," >&2
    echo "or pass its path: scripts/setup.sh path/to/archive.tar.gz" >&2
    exit 1
fi

if [[ "$(uname -s)" != "Linux" || "$(uname -m)" != "x86_64" ]]; then
    echo "error: the binaries are built for Linux x86_64, this is $(uname -s) $(uname -m)" >&2
    exit 1
fi

# The binaries need glibc 2.34 or newer (Ubuntu 22.04+, Debian 12+).
glibc="$(ldd --version 2>/dev/null | head -n1 | grep -oE '[0-9]+\.[0-9]+$' || true)"
if [[ -n "$glibc" ]]; then
    if [[ "$(printf '%s\n2.34\n' "$glibc" | sort -V | head -n1)" != "2.34" ]]; then
        echo "error: glibc $glibc found, the binaries need 2.34 or newer (Ubuntu 22.04+, Debian 12+)" >&2
        exit 1
    fi
else
    echo "warning: could not determine the glibc version; the binaries need 2.34 or newer" >&2
fi

echo "unpacking $archive"
tar xzf "$archive" epiql epiql-web
chmod +x epiql epiql-web
./epiql --help > /dev/null
echo "ready: ./epiql and ./epiql-web"
echo "next:  scripts/demo.sh   (command line)   or   scripts/web.sh   (web interface)"

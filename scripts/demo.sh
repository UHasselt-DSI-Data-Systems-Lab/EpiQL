#!/usr/bin/env bash
# Run a simulation with the command line and print a summary of the outcome.
#
#   scripts/demo.sh                  # config.json: the Tiny Town demo, 20 runs of 60 days
#   scripts/demo.sh my-config.json   # any other config file
#
# Each call writes to a fresh folder runs/<date-time>/output, so earlier results are kept.
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"

config="$(realpath "${1:-$root/config.json}")"
if [[ ! -x "$root/epiql" ]]; then
    echo "error: $root/epiql not found; run scripts/setup.sh first" >&2
    exit 1
fi

# output_dir in the config is relative to the current directory, so run from a new one.
dir="$root/runs/$(date +%Y-%m-%d_%H-%M-%S)"
mkdir -p "$dir"
cd "$dir"
"$root/epiql" --config "$config"
out="$dir/$(grep -oE '"output_dir"[[:space:]]*:[[:space:]]*"[^"]*"' "$config" | sed -E 's/.*"([^"]*)"$/\1/')"

# value FILE: the single number in an aggregate output file, 0 if it is empty or missing.
value() { local v; v="$(head -n1 "$1" 2>/dev/null || true)"; echo "${v:-0}"; }

if ! ls "$out"/run_0/NewlyInfected@0.* > /dev/null 2>&1; then
    echo
    echo "results in $out"
    exit 0
fi
ext="$(ls "$out"/run_0/NewlyInfected@0.* | head -n1 | sed 's/.*\.//')"
if [[ "$ext" != "csv" ]]; then
    echo
    echo "results ($ext) in $out; set \"output_format\": \"csv\" for a summary here"
    exit 0
fi

days="$(ls "$out"/run_0/NumInfectious@*.csv | wc -l)"
echo
echo "run  infected  peak infectious  (day)"
for run in "$out"/run_*; do
    total=0; peak=0; peak_day=0
    for ((t = 0; t < days; t++)); do
        total=$((total + $(value "$run/NewlyInfected@$t.csv")))
        n="$(value "$run/NumInfectious@$t.csv")"
        if ((n > peak)); then peak=$n; peak_day=$t; fi
    done
    printf "%3s  %8d  %15d  (%s)\n" "${run##*_}" "$total" "$peak" "$peak_day"
done | sort -n

# Sum of infectious people over all runs, per day; the chart stops after the last day
# on which anyone is infectious.
sums=(); last=0
for ((t = 0; t < days; t++)); do
    sum=0
    for run in "$out"/run_*; do sum=$((sum + $(value "$run/NumInfectious@$t.csv"))); done
    sums[t]=$sum
    if ((sum > 0)); then last=$t; fi
done
runs="$(ls -d "$out"/run_* | wc -l)"
echo
echo "mean number of infectious people per day, over all $runs runs (# = 0.05):"
for ((t = 0; t <= last; t++)); do
    LC_ALL=C awk -v t="$t" -v s="${sums[t]}" -v r="$runs" 'BEGIN {
        m = s / r; bar = ""; for (i = 0; i < int(m * 20 + 0.5); i++) bar = bar "#";
        printf "day %3d  %5.2f  %s\n", t, m, bar }'
done
if ((last < days - 1)); then echo "nobody is infectious after day $last"; fi

echo
echo "results in $out"

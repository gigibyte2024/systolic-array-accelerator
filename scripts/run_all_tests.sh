#!/usr/bin/env bash
#
# Regression runner: compiles and runs every testbench with Icarus Verilog
# and prints a pass/fail summary.
#
# Usage (from anywhere inside the repository):
#   scripts/run_all_tests.sh           all tests, N=100 system run skipped
#   scripts/run_all_tests.sh --full    also run the slow N=100 cases
#   scripts/run_all_tests.sh --waves   write waveforms (.vcd) into the repo
#   scripts/run_all_tests.sh --help
#
# By default the simulations run in a temporary folder, so the committed
# .vcd waveform files are not modified.
#
# A test passes only if it compiles, exits with status 0, prints "PASS"
# and prints no "FAIL" or "FATAL".
# Exit status: 0 if every test passed, 1 otherwise.

set -u

FULL=0
WAVES=0
for arg in "$@"; do
    case "$arg" in
        --full)  FULL=1 ;;
        --waves) WAVES=1 ;;
        -h|--help)
            sed -n '3,17p' "$0" | sed 's/^# \{0,1\}//'
            exit 0 ;;
        *)
            echo "Unknown option: $arg (try --help)"
            exit 2 ;;
    esac
done

ROOT="$(cd "$(dirname "$0")/.." && pwd)"

if ! command -v iverilog >/dev/null 2>&1 || ! command -v vvp >/dev/null 2>&1; then
    echo "Icarus Verilog not found. Install it first (macOS: brew install icarus-verilog)."
    exit 2
fi

WORK="$(mktemp -d "${TMPDIR:-/tmp}/systolic_regress.XXXXXX")"
if [ "$WAVES" -eq 1 ]; then
    RUN_DIR="$ROOT"
else
    RUN_DIR="$WORK"
    mkdir -p "$RUN_DIR/simulation" \
             "$RUN_DIR/report/member3/waveforms" \
             "$RUN_DIR/report/member5/waveforms"
fi

RTL="$ROOT/rtl/*.v"

# Test list: "testbench|parameter overrides (space separated N values)".
# Testbenches not listed here run once with their default parameters.
SWEEPS="
tb_array_n_sweep|2 3 4 5 8
tb_system_random_regression|2 3 4 5 8
tb_member5_verification|2 3 4
tb_controller_stress|1 2 4 8 100
"
if [ "$FULL" -eq 1 ]; then
    SWEEPS="
tb_array_n_sweep|2 3 4 5 8 100
tb_system_random_regression|2 3 4 5 8 100
tb_member5_verification|2 3 4
tb_controller_stress|1 2 4 8 100
"
fi

sweep_values() {
    echo "$SWEEPS" | grep "^$1|" | cut -d'|' -f2
}

PASSED=0
FAILED=0
FAILED_NAMES=""
START_ALL=$SECONDS

run_one() {
    # $1 = testbench module, $2 = N override (empty for default)
    local tb="$1" n="$2" label="$1" pflag="" log t0 dt status
    if [ -n "$n" ]; then
        label="$tb (N=$n)"
        pflag="-P$tb.N=$n"
    fi
    log="$WORK/${tb}${n:+_N$n}.log"
    t0=$SECONDS

    status=0
    # shellcheck disable=SC2086
    if ! iverilog -g2012 -s "$tb" $pflag -o "$WORK/sim.vvp" $RTL "$ROOT/testbench/$tb.v" >"$log" 2>&1; then
        status=1
    elif ! (cd "$RUN_DIR" && vvp "$WORK/sim.vvp") >>"$log" 2>&1; then
        status=1
    elif ! grep -q "PASS" "$log"; then
        status=1
    elif grep -qE "FAIL|FATAL" "$log"; then
        status=1
    fi
    dt=$((SECONDS - t0))

    if [ "$status" -eq 0 ]; then
        PASSED=$((PASSED + 1))
        printf "  PASS  %-46s %4ss\n" "$label" "$dt"
    else
        FAILED=$((FAILED + 1))
        FAILED_NAMES="$FAILED_NAMES
    $label  (log: $log)"
        printf "  FAIL  %-46s %4ss\n" "$label" "$dt"
        tail -n 8 "$log" | sed 's/^/        | /'
    fi
}

echo "Systolic array regression  (Icarus Verilog $(iverilog -V 2>/dev/null | head -1 | awk '{print $4}'))"
[ "$FULL" -eq 0 ] && echo "Quick mode: N=100 array and system runs skipped (use --full)."
echo

for f in "$ROOT"/testbench/tb_*.v; do
    tb="$(basename "$f" .v)"
    values="$(sweep_values "$tb")"
    if [ -n "$values" ]; then
        for n in $values; do
            run_one "$tb" "$n"
        done
    else
        run_one "$tb" ""
    fi
done

TOTAL=$((PASSED + FAILED))
echo
echo "----------------------------------------------------------------"
echo "  $PASSED / $TOTAL passed   ($((SECONDS - START_ALL))s)"
if [ "$FAILED" -eq 0 ]; then
    echo "  ALL TESTS PASSED"
    echo "----------------------------------------------------------------"
    rm -rf "$WORK"
    exit 0
else
    echo "  $FAILED FAILED:$FAILED_NAMES"
    echo "  Logs kept in: $WORK"
    echo "----------------------------------------------------------------"
    exit 1
fi

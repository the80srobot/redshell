#!/bin/bash
# Smoke tests for the q dispatch function

SRC_DIR="${1}"

pushd "${SRC_DIR}" > /dev/null
source "compat.sh"
# Source minimal dependencies for quick.bash
source "strings.bash" 2>/dev/null || true
source "path.bash" 2>/dev/null || true
source "python.bash" 2>/dev/null || true
source "quick.gen.bash" 2>/dev/null || true
source "quick.bash" 2>/dev/null || true
popd > /dev/null

FAILURES=0

# Test: q function is defined
if ! type q > /dev/null 2>&1; then
    echo "FAIL: q function not defined" >&2
    (( FAILURES++ ))
fi

# Test: __q function is defined (generated dispatch)
if ! type __q > /dev/null 2>&1; then
    echo "FAIL: __q function not defined" >&2
    (( FAILURES++ ))
fi

# Test: __q_help function is defined
if ! type __q_help > /dev/null 2>&1; then
    echo "FAIL: __q_help function not defined" >&2
    (( FAILURES++ ))
fi

# Test: q with no args produces output (module list)
result="$(q 2>&1)"
if [[ -z "${result}" ]]; then
    echo "FAIL: q with no args produced no output" >&2
    (( FAILURES++ ))
fi

if [[ "${FAILURES}" -gt 0 ]]; then
    echo "${FAILURES} test(s) failed" >&2
    exit 1
fi

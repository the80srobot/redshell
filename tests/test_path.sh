#!/bin/bash
# Tests for path.bash functions

SRC_DIR="${1}"

# Source compat first, then path (and its dependencies)
pushd "${SRC_DIR}" > /dev/null
source "compat.sh"
source "strings.bash" 2>/dev/null || true
source "screen.bash" 2>/dev/null || true
source "path.bash"
popd > /dev/null

FAILURES=0

assert_eq() {
    local actual="$1"
    local expected="$2"
    local msg="${3:-}"
    if [[ "${actual}" != "${expected}" ]]; then
        echo "FAIL: expected '${expected}', got '${actual}' ${msg}" >&2
        (( FAILURES++ ))
    fi
}

# Test: path_expand with tilde
result="$(path_expand "~/foo")"
assert_eq "${result}" "${HOME}/foo" "(path_expand ~/foo)"

# Test: path_expand with multiple path elements
result="$(path_expand "~/a:~/b")"
assert_eq "${result}" "${HOME}/a:${HOME}/b" "(path_expand ~/a:~/b)"

# Test: path_expand with no tilde
result="$(path_expand "/usr/bin")"
assert_eq "${result}" "/usr/bin" "(path_expand /usr/bin)"

# Test: path_resolve with existing directory
result="$(path_resolve "/tmp")"
# /tmp may be a symlink on macOS, so just check it resolves to something
if [[ -z "${result}" ]]; then
    echo "FAIL: path_resolve /tmp returned empty" >&2
    (( FAILURES++ ))
fi

if [[ "${FAILURES}" -gt 0 ]]; then
    echo "${FAILURES} test(s) failed" >&2
    exit 1
fi

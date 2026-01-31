#!/bin/bash
# Tests for the compatibility layer (compat.sh)

SRC_DIR="${1}"
source "${SRC_DIR}/compat.sh"

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

# Test: _REDSHELL_READ_ARRAY_FLAG is set
if [[ -z "${_REDSHELL_READ_ARRAY_FLAG}" ]]; then
    echo "FAIL: _REDSHELL_READ_ARRAY_FLAG not set" >&2
    (( FAILURES++ ))
fi

# Test: _REDSHELL_ZSH is set correctly
if [[ -n "${ZSH_VERSION:-}" ]]; then
    assert_eq "${_REDSHELL_ZSH}" "1" "(_REDSHELL_ZSH in zsh)"
    assert_eq "${_REDSHELL_READ_ARRAY_FLAG}" "-A" "(read flag in zsh)"
else
    assert_eq "${_REDSHELL_ZSH}" "" "(_REDSHELL_ZSH in bash)"
    assert_eq "${_REDSHELL_READ_ARRAY_FLAG}" "-a" "(read flag in bash)"
fi

# Test: _printf_v function exists
if ! type _printf_v > /dev/null 2>&1; then
    echo "FAIL: _printf_v not defined" >&2
    (( FAILURES++ ))
fi

# Test: _printf_v produces correct output
_printf_v result '%s' "hello"
assert_eq "${result}" "hello" "(_printf_v basic)"

_printf_v result '%s' "foo:bar"
assert_eq "${result}" "foo:bar" "(_printf_v with colon)"

# Test: read with array flag works (in a function with emulate -L ksh, as used in practice)
_test_read_array() {
    [[ -n "${_REDSHELL_ZSH}" ]] && emulate -L ksh
    IFS=':' read -r ${_REDSHELL_READ_ARRAY_FLAG} arr <<< "a:b:c"
    assert_eq "${arr[0]}" "a" "(read array element 0)"
    assert_eq "${arr[1]}" "b" "(read array element 1)"
    assert_eq "${arr[2]}" "c" "(read array element 2)"
}
_test_read_array

if [[ "${FAILURES}" -gt 0 ]]; then
    echo "${FAILURES} test(s) failed" >&2
    exit 1
fi

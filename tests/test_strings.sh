#!/bin/bash
# Tests for strings.bash functions

SRC_DIR="${1}"

pushd "${SRC_DIR}" > /dev/null
source "compat.sh"
# strings.bash sources go.bash, which may not be available in test env
# Override the go_pkg_do function to avoid errors
function go_pkg_do() { return 1; }
source "strings.bash"
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

# Test: strings_repeat
result="$(strings_repeat "x" 3)"
assert_eq "${result}" "xxx" "(strings_repeat x 3)"

result="$(strings_repeat "ab" 2)"
assert_eq "${result}" "abab" "(strings_repeat ab 2)"

# Test: strings_join
result="$(strings_join "," "a" "b" "c")"
assert_eq "${result}" "a,b,c" "(strings_join comma)"

result="$(strings_join "/" "usr" "local" "bin")"
assert_eq "${result}" "usr/local/bin" "(strings_join slash)"

# Test: strings_trim
result="$(strings_trim "  hello  ")"
assert_eq "${result}" "hello" "(strings_trim spaces)"

result="$(strings_trim "nowhitespace")"
assert_eq "${result}" "nowhitespace" "(strings_trim no change)"

# Test: strings_strip_prefix
result="$(strings_strip_prefix "foo" "foobar")"
assert_eq "${result}" "bar" "(strings_strip_prefix match)"

result="$(strings_strip_prefix "xyz" "foobar")"
assert_eq "${result}" "foobar" "(strings_strip_prefix no match)"

# Test: strings_elide (short string, no elision)
result="$(strings_elide "hello" 100)"
assert_eq "${result}" "hello" "(strings_elide short)"

if [[ "${FAILURES}" -gt 0 ]]; then
    echo "${FAILURES} test(s) failed" >&2
    exit 1
fi

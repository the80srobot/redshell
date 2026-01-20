#!/bin/bash
# Tests for file.bash functions

SRC_DIR="${1}"

pushd "${SRC_DIR}" > /dev/null
source "compat.sh"
source "file.bash"
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

# Test: file_mktemp creates a file
result="$(file_mktemp "redshell_test")"
if [[ ! -f "${result}" ]]; then
    echo "FAIL: file_mktemp did not create a file" >&2
    (( FAILURES++ ))
else
    rm -f "${result}"
fi

# Test: file_mtime returns non-empty for existing file
tmpfile="$(file_mktemp "redshell_mtime_test")"
result="$(file_mtime "${tmpfile}")"
if [[ -z "${result}" ]]; then
    echo "FAIL: file_mtime returned empty for existing file" >&2
    (( FAILURES++ ))
fi
rm -f "${tmpfile}"

# Test: file_mtime returns error for non-existent file
if file_mtime "/nonexistent/path/file" 2>/dev/null; then
    echo "FAIL: file_mtime should fail for non-existent file" >&2
    (( FAILURES++ ))
fi

# Test: file_age -s returns a number for existing file
tmpfile="$(file_mktemp "redshell_age_test")"
result="$(file_age -s "${tmpfile}")"
if ! [[ "${result}" =~ ^[0-9]+$ ]]; then
    echo "FAIL: file_age -s did not return a number, got '${result}'" >&2
    (( FAILURES++ ))
fi
rm -f "${tmpfile}"

if [[ "${FAILURES}" -gt 0 ]]; then
    echo "${FAILURES} test(s) failed" >&2
    exit 1
fi

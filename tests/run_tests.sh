#!/bin/bash
# Test runner for redshell. Executes each test file under both bash and zsh.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC_DIR="$(cd "${SCRIPT_DIR}/../src" && pwd)"

PASS=0
FAIL=0
SKIP=0

run_test() {
    local shell="$1"
    local test_file="$2"
    local test_name="$(basename "${test_file}" .sh)"

    if ! command -v "${shell}" > /dev/null 2>&1; then
        echo "  SKIP [${shell}] ${test_name} (${shell} not found)"
        SKIP=$((SKIP + 1))
        return 0
    fi

    local output
    if output="$("${shell}" "${test_file}" "${SRC_DIR}" 2>&1)"; then
        echo "  PASS [${shell}] ${test_name}"
        PASS=$((PASS + 1))
    else
        echo "  FAIL [${shell}] ${test_name}"
        echo "${output}" | sed 's/^/       /'
        FAIL=$((FAIL + 1))
    fi
}

echo "Running redshell tests..."
echo "Source directory: ${SRC_DIR}"
echo ""

for test_file in "${SCRIPT_DIR}"/test_*.sh; do
    [[ -f "${test_file}" ]] || continue
    run_test bash "${test_file}"
    run_test zsh "${test_file}"
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed, ${SKIP} skipped"

if [[ "${FAIL}" -gt 0 ]]; then
    exit 1
fi

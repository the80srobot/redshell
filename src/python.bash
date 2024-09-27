# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Python env management, python-shell FFI and Jupyter.

if [[ -z "${_REDSHELL_PYTHON}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PYTHON=1

function __python_ensurepip() {
    local pythonpath="$1"
    "${pythonpath}" -m ensurepip --upgrade
    if [[ "$?" -ne 0 ]]; then
        >&2 echo "Retrying with --break-system-packages..."
        "${pythonpath}" -m ensurepip --upgrade --break-system-packages
        return $?
    fi
}

function __python_ensurevenv() {
    local pythonpath="$1"
    "${pythonpath}" -m pip install virtualenv
    if [[ "$?" -ne 0 ]]; then
        >&2 echo "Retrying with --break-system-packages..."
        "${pythonpath}" -m pip install virtualenv --break-system-packages
        return $?
    fi
}

# virtualenv is stupid and completely ignores --python and VIRTUALENV_PYTHON. Go
# in and fix it manually.
function __fix_stupid_virtualenv_behavior() {
    local pythonpath="$1"
    local venvpath="$2"
    pushd "${venvpath}/bin" || return 1
    rm -f python || return 2
    ln -s "${pythonpath}" python || return 3
    popd
}

# Usage: python_venv [-I|--install-requirements] [-p|--python-path PATH] [-q|--quiet] [VERSION]
#
# Create a new virtualenv in the current directory, using the latest available
# python version. If a virtualenv already exists, activate it. If -I is passed,
# install requirements.txt. If -p is passed, use the specified Python binary. If
# VERSION is passed, find a python binary with that version.
function python_venv() {
    local install_reqs=""
    local stderr=/dev/stderr
    local pythonpath="$(python_latest)"

    while [[ "${#}" -ne 0 ]]; do
        case "$1" in
            -I|--install-requirements)
                install_reqs="requirements.txt"
                ;;
            -p|--python-path)
                pythonpath="$(which "$2")"
                shift
                ;;
            -q|--quiet)
                stderr=/dev/null
                ;;
            *)
                pythonpath="$(which "python$1")"
                ;;
        esac
        shift
    done
    echo "Using Python: ${pythonpath}" >$stderr

    # Ensure PIP is installed.
    "${pythonpath}" -m pip --help 2> /dev/null > /dev/null \
        || __python_ensurepip "${pythonpath}" 2> $stderr
    
    if [[ -d "./.venv" ]]; then
        echo "Activating existing environment" >$stderr
        source ./.venv/bin/activate
        if [[ -n "${install_reqs}" ]]; then
            pip install --upgrade -r "${install_reqs}" 2> $stderr
        fi
        return 0
    fi

    echo "Creating a new virtualenv..." >$stderr
    "${pythonpath}" -m virtualenv --help 2> /dev/null > /dev/null
    if [[ "$?" -ne 0 ]]; then
        >&2 echo "Installing virtualenv..."
        __python_ensurevenv "${pythonpath}" 2> $stderr || return 2
    fi

    echo "Creating virtualenv in $(pwd)/.venv with ${pythonpath}" >$stderr
    "${pythonpath}" -m virtualenv \
        --python="${pythonpath}" \
        .venv \
        2> $stderr || return 3
    __fix_stupid_virtualenv_behavior "${pythonpath}" "$(pwd)/.venv" 2> $stderr || return $?
    source ./.venv/bin/activate
    pip install --upgrade pip 2> $stderr
    [[ -f requirements.txt ]] && pip install --upgrade -r requirements.txt 2> $stderr
    echo "Virtualenv created" >$stderr
}

alias venv=python_venv

# Usage: python_ipynb [-I|--install-requirements] [-p|--python-path PATH] [VERSION]
#
# Creates a new virtualenv in the current directory (as venv) and opens a new
# Jupyter notebook.
function python_ipynb() {
    python_venv "${@}"
    touch ./nb.ipynb
    e .
    e ./nb.ipynb
}

alias ipynb=python_ipynb

# Usage: python_detect
#
# Find all available Python binaries in the PATH and their versions.
# Prints a tab-separated list: VERSION  PATH  SHORT_VERSION
function python_detect() {
    IFS=: read -r -d '' -a path_array <<< "${PATH}"
    for p in "${path_array[@]}"; do
        [[ -d "${p}" ]] || continue
        find "${p}" -maxdepth 1 -name 'python*'
    done | \
    grep -E "python[0-9.]+$" | sort -u | {
        while IFS= read -r line; do
            if [[ -x "${line}" ]]; then
                local real_version="$(${line} --version 2>&1 | head -n1)"
                real_version="${real_version##*Python }"
                local short_version="${line##*python}"
                printf "%s\t%s\t%s\n" "${real_version}" "${line}" "${short_version}"
            fi
        done
    } | sort -Vr
}

# Usage: python_latest
#
# Returns the path to the latest available Python binary.
function python_latest() {
    # TODO: this is a hack to work around environments with special blessed
    # python versions, but actually it should be made user-selectable.
    local path=~/.redshell_persist/python_path
    if [[ -f "${path}" ]]; then
        cat "${path}"
    else
        python_detect | head -n1 | cut -f2
    fi
}

# Usage: python_func -f|--function FUNCTION -p|--path PATH [-J|--json_output] [--clean] [--debug] [--quiet] [--] [ARGS...]
#
# Run a Python function from a file. Calls `q python venv` to setup the
# environment. The function must be defined in the file and must be a top-level
# function. The function must be defined with type hints for all arguments.
#
# Function arguments are passed as positional arguments or keyword arguments.
# Keyword arguments are passed as --KEY VALUE. Positional arguments are passed
# after a single --.
#
# Example: python_func -f my_function -p my_file.py --kwarg val -- --arg1 arg2
#
# Arguments:
# -f|--function: The name of the function to run.
# -p|--path: The path to the Python file.
# -J|--json-output: Serialize the output as JSON.
# --clean: Delete the virtualenv after running the function.
# --debug: Print the Python script that was executed.
# --quiet: Do not print any output from the virtualenv creation.
function python_func() {
    local function
    local json_out="False"
    local path="${HOME}/.redshell/functions.py"
    local args="["
    local kwargs="{"
    local clean=""
    local debug
    local quiet

    while [[ "${#}" -ne 0 ]]; do
        case "$1" in
            -f|--function)
                function="$2"
                shift
                ;;
            -p|--path)
                path="$2"
                shift
                ;;
            -J|--json-output)
                json_out="True"
                ;;
            --clean)
                clean="True"
                ;;
            --debug)
                debug="True"
                ;;
            --quiet)
                quiet="True"
                ;;
            --)
                shift
                break;
                ;;
            *)
                # Assume positional function name. Implies --.
                function="$1"
                shift
                break
            ;;
        esac
        shift
    done

    while [[ "${#}" -ne 0 ]]; do
        if [[ "${1:0:2}" == "--" ]]; then
            kwargs+="$(printf 'r"%q": r"%q"' "${1:2}" "${2}"),"
            shift
        else
            args+="$(printf 'r"%q", ' "${1}")"
        fi
        shift
    done
    kwargs+="}"
    args+="]"

    if [[ -z "${function}" ]]; then
        >&2 echo "No function specified"
        return 1
    fi

    if [[ -z "${path}" ]]; then
        >&2 echo "No path specified"
        return 2
    fi

    pushd "$(dirname "${path}")" > /dev/null
    if [[ -n "${quiet}" ]]; then
        python_venv --quiet
    else
        python_venv
    fi

    script="from $(basename "${path}" .py) import *
import typing
import shlex
import datetime
kwargs = ${kwargs}
args = ${args}
json_out = ${json_out}

def __convert_arg(
    arg: str, arg_type: typing.Any
) -> typing.Any:
    try:
        if arg_type is None:
            return arg
        if arg_type == bool:
            return arg.lower() == 'true'
        if arg_type == int:
            return int(arg)
        if arg_type == float:
            return float(arg)
        if arg_type == str:
            return shlex.split(arg)[0]
        if arg_type == datetime.date:
            return datetime.date.fromisoformat(arg)
        if arg_type == list[str]:
            return shlex.split(arg)[0].split(',')
        if typing.get_origin(arg_type) == typing.Union:
            type_args = typing.get_args(arg_type)
            if len(type_args) == 2 and type_args[1] == type(None):
                return __convert_arg(arg, type_args[0])
            elif len(type_args) == 2 and type_args[0] == type(None):
                return __convert_arg(arg, type_args[1])
        if isinstance(arg_type, typing.Callable):
            return eval(arg)
    except Exception as e:
        raise TypeError('Cannot parse {} of type {}: {}'.format(arg, arg_type, e))
    
    raise ValueError('Unknown type: {}'.format(arg_type))

def __json_default(obj: typing.Any) -> typing.Any:
    serializer = getattr(obj, 'toJSON', None)
    if not callable(serializer):
        return str(obj)

    return serializer()

def __convert_args(
    func: typing.Callable, args: list[str], kwargs: dict[str, str]
) -> dict[str, typing.Any]:
    hints = typing.get_type_hints(func)
    arg_names = func.__code__.co_varnames
    converted_args = {}
    for i, arg in enumerate(args):
        arg_name = arg_names[i]
        converted_args[arg_name] = __convert_arg(arg, hints.get(arg_name))

    for arg_name, arg in kwargs.items():
        converted_args[arg_name] = __convert_arg(arg, hints.get(arg_name))
    return converted_args

try:
    kwargs = __convert_args(${function}, args, kwargs)
    res = ${function}(**kwargs)
    if json_out:
        import json
        from typing import Generator
        if isinstance(res, Generator):
            res = list(res)
        print(json.dumps(res, default=__json_default))
    else:
        print(res)
except Exception as e:
    import sys
    import traceback
    sys.stderr.write(traceback.format_exc()+'\n')
    sys.exit(1)
"
    local ret
    python -c "${script}"
    ret="$?"

    deactivate
    if [[ -n "${clean}" ]]; then
        >&2 echo "Cleaning up..."
        rm -rf .venv
        rm -rf __pycache__
    fi

    popd > /dev/null
    
    if [[ "${ret}" -ne 0 || -n "${debug}" ]]; then
        >&2 echo "Python function exited with code ${ret}"
        >&2 echo "(function: ${function} path: ${path})"
        >&2 echo "Script dump:"

        local i=1
        while IFS= read -r line; do
            printf "%3d %s\n" "${i}" "${line}" >&2
            ((i++))
        done < <(echo "${script}")
    fi
    
    return "${ret}"
}

# Usage: python_black [FILES...]
#
# Run the black code formatter on the specified files.
function python_black() {
    mkdir -p "$HOME/.redshell/python_black"
    pushd "$HOME/.redshell/python_black"
    echo "black" > requirements.txt
    python_venv
    popd
    python -m black "${@}"
    deactivate
}

fi # _REDSHELL_PYTHON

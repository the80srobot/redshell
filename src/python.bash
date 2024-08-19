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

function venv() {
    local install_reqs=""
    local pythonpath="$(latest_python)"
    echo "Using Python: ${pythonpath}" >&2

    while [[ "${#}" -ne 0 ]]; do
        case "$1" in
            -I|--install-requirements)
                install_reqs="requirements.txt"
                ;;
            -p|--python-path)
                pythonpath="$(which "$2")"
                shift
                ;;
            *)
                pythonpath="$(which "python$1")"
                ;;
        esac
        shift
    done

    # Ensure PIP is installed.
    "${pythonpath}" -m pip --help 2> /dev/null > /dev/null \
        || __python_ensurepip "${pythonpath}"
    
    if [[ -d "./.venv" ]]; then
        echo "Activating existing environment" >&2
        source ./.venv/bin/activate
        if [[ -n "${install_reqs}" ]]; then
            pip install --upgrade -r "${install_reqs}"
        fi
        return 0
    fi

    echo "Creating a new virtualenv..." >&2
    "${pythonpath}" -m virtualenv --help 2> /dev/null > /dev/null
    if [[ "$?" -ne 0 ]]; then
        >&2 echo "Installing virtualenv..."
        __python_ensurevenv "${pythonpath}" || return 2
    fi

    echo "Creating virtualenv in $(pwd)/.venv with ${pythonpath}" >&2
    "${pythonpath}" -m virtualenv --python="${pythonpath}" .venv  || return 3
    source ./.venv/bin/activate
    pip install --upgrade pip
    [[ -f requirements.txt ]] && pip install --upgrade -r requirements.txt
}

function ipynb() {
    venv "${@}"
    touch ./nb.ipynb
    e .
    e ./nb.ipynb
}

function detect_python() {
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

function latest_python() {
    # TODO: this is a hack to work around environments with special blessed
    # python versions, but actually it should be made user-selectable.
    local path=~/.redshell_persist/python_path
    if [[ -f "${path}" ]]; then
        cat "${path}"
    else
        detect_python | head -n1 | cut -f2
    fi
}

# Usage: python_func -f|--function FUNCTION -p|--path PATH [-J|--json_output] [--clean] [--debug] [--] [ARGS...]
function python_func() {
    local function
    local json_out="False"
    local path="${HOME}/.redshell/functions.py"
    local args="["
    local kwargs="{"
    local clean=""
    local debug

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
    venv >&2

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
function python_black() {
    mkdir -p "$HOME/.redshell/python_black"
    pushd "$HOME/.redshell/python_black"
    echo "black" > requirements.txt
    venv
    popd
    python -m black "${@}"
    deactivate
}

fi # _REDSHELL_PYTHON

# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# This file provides functions to manage python environments, and quickly launch
# python code in various ways. It includes a Bash-Python FFI bridge, in
# python_func.

if [[ -z "${_REDSHELL_PYTHON}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_PYTHON=1

function venv() {
    local install_reqs=""
    local pythonpath="$(latest_python)"

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

    # Ensure PIP and virtualenv are installed.
    "${pythonpath}" -m pip --help 2> /dev/null > /dev/null \
        || "${pythonpath}" -m ensurepip --upgrade
    
    "${pythonpath}" -m virtualenv --help 2> /dev/null > /dev/null \
        || "${pythonpath}" -m pip install virtualenv --break-system-packages

    if [[ -d "./.venv" ]]; then
        source ./.venv/bin/activate
        if [[ -n "${install_reqs}" ]]; then
            pip install --upgrade -r "${install_reqs}"
        fi
        return 0
    fi

    "${pythonpath}" -m virtualenv --help 2> /dev/null > /dev/null
    if [[ "$?" -ne 0 ]]; then
        >&2 echo "Installing virtualenv..."
        python3 -m pip install virtualenv || return 2
    fi

    "${pythonpath}" -m virtualenv .venv || return 3
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
    detect_python | head -n1 | cut -f2
}

function python_func() {
    local function
    local json_out="False"
    local path="${HOME}/.redshell/functions.py"
    local args="["
    local kwargs="{"

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
            kwargs+="$(printf '"%q": "%q"' "${1:2}" "${2}"),"
            shift
        else
            args+="$(printf '"%q", ' "${1}")"
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
    venv

    script="from $(basename "${path}" .py) import *
import typing
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
            return arg
        if arg_type == datetime.date:
            return datetime.date.fromisoformat(arg)
        if typing.get_origin(arg_type) == typing.Union:
            type_args = typing.get_args(arg_type)
            if len(type_args) == 2 and type_args[1] == type(None):
                return __convert_arg(arg, type_args[0])
            elif len(type_args) == 2 and type_args[0] == type(None):
                return __convert_arg(arg, type_args[1])
        if isinstance(arg_type, Callable):
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
        print(json.dumps(res, default=__json_default))
    else:
        print(res)
except Exception as e:
    import sys
    import traceback
    sys.stderr.write(traceback.format_exc()+'\n')
    sys.exit(1)
"

    python -c "${script}"

    deactivate
    popd > /dev/null
}

fi # _REDSHELL_PYTHON

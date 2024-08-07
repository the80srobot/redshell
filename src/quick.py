# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# This script regenerates quick.gen.bash from the source files in src/. It's mostly
# a janky bash function parser that only handles the cases we use in this
# project.
#
# To regen quick.gen.bash, just run `q quick rebuild``.

import os
import dataclasses
from dataclasses import dataclass
from typing import Iterable, Generator
from enum import Enum
import re
import sys
import shlex


@dataclass
class Token:
    value: str
    start: tuple[int, int]
    end: tuple[int, int]


class ArgumentType(Enum):
    DEFAULT = 1
    SWITCH = 2
    FILE = 3
    DIRECTORY = 4
    STRING = 5
    USER = 7
    GROUP = 8
    HOSTNAME = 9


@dataclass
class Argument:
    name: str
    type: ArgumentType
    type_name: str
    default: str
    required: bool = False
    repeated: bool = False
    position: int | None = None
    aliases: Iterable[str] = ()


@dataclass
class Function:
    name: Token
    package: str
    comment: list[str]
    usage: str
    args: list[Argument]


@dataclass
class Module:
    name: str
    functions: list[Function]
    comment: list[str]


FNAME_TYPE_A = re.compile(r"([\w\-_]+)\s*\(\)\s")
FNAME_TYPE_B = re.compile(r"function\s+([\w\-_]+)[\s(]")


def _escape_comment(comment: list[str]) -> Generator[str, None, None]:
    for line in comment:
        quoted = shlex.quote(line)
        if quoted.startswith("'") and quoted.endswith("'"):
            yield quoted[1:-1]
        else:
            yield quoted
    # return (shlex.quote(line)[1:-1] for line in comment)


def _accept_fname(line: str) -> tuple[str, tuple[int, int]] | None:
    # Bash supports two variants of declaration syntax:
    # Type A: fname () compound-command [ redirections ]
    # Type B: function fname [()] compound-command [ redirections ]

    if m := FNAME_TYPE_A.match(line):
        return m.group(1), m.span(1)
    elif m := FNAME_TYPE_B.match(line):
        return m.group(1), m.span(1)
    else:
        return None


def _accept_comment(line: str) -> str | None:
    if line.startswith("#"):
        return line[1:].strip()
    else:
        return None


def _parse_arg_type(s: str) -> ArgumentType:
    if s.lower().endswith("file") or s.lower().endswith("path"):
        return ArgumentType.FILE
    if s.lower().endswith("dir") or s.lower().endswith("directory"):
        return ArgumentType.DIRECTORY
    if s.lower().endswith("user"):
        return ArgumentType.USER
    if s.lower().endswith("group"):
        return ArgumentType.GROUP
    if s.lower().endswith("host") or s.lower().endswith("hostname"):
        return ArgumentType.HOSTNAME
    if s.lower().endswith("string"):
        return ArgumentType.STRING
    if s == "ARG":
        return ArgumentType.DEFAULT
    return ArgumentType.STRING


def _finalize_arguments(raw: list[Argument]) -> list[Argument]:
    args = []
    for i, raw_arg in enumerate(raw):
        arg = dataclasses.replace(raw_arg)
        # Expand aliases:
        arg.name = arg.name.strip()
        names = arg.name.split("|")

        if len(names) > 1:
            arg.name = names[0]
            arg.aliases = names[1:]

        # If the argument starts with a dash, it's either a switch or a keyword
        # argument. Which one it is depends on whether it's followed by:
        #
        # 1. Another argument
        # 2. Which does NOT start with a dash
        # 3. And whose optional flag is the same as this argument's

        if arg.name.startswith("-"):
            # We default to thinking this is a switch, but if the next argument
            # looks like it's the type for this one, we'll change our mind.
            # Example: --path PATH. We are at --path, and start out thinking
            # it's a switch. But then we see PATH, and realize that --path takes
            # a value of type PATH.
            arg.type = ArgumentType.SWITCH
            args.append(arg)
        else:
            if i != 0 and raw[i - 1].name.startswith("-") and raw[i - 1].name:
                args[-1].type = _parse_arg_type(arg.name)
                args[-1].type_name = arg.name
            else:
                # This is a positional argument.
                args.append(arg)
                arg.position = len(args)

    return args


def _parse_usage(usage: str) -> tuple[str, list[Argument]]:
    args = []  # result
    # state - remaining string and character position
    s = usage
    n = 0
    # While this is true, arguments are parsed as optional.
    # Set/unset by '[' and ']'.
    optional = False
    prev_token = "BEGIN"

    # Single-pass state machine. s is consumed from the left, until it's empty.
    while s:
        if m := re.match(r"\s*\[", s):
            if optional:
                raise ValueError(f"Unexpected '[' after position {n}: {usage}")
            optional = True
            s = s[m.end() :]
            n += m.end()
            prev_token = "LBRACKET"
        elif m := re.match(r"\s*\]", s):
            if not optional:
                raise ValueError(f"Unexpected ']' after position {n}: {usage}")
            optional = False
            s = s[m.end() :]
            n += m.end()
            prev_token = "RBRACKET"
        elif m := re.match(r"\s*([a-z|A-Z_0-9\-]+)", s):
            s = s[m.end() :]
            n += m.end()
            if prev_token == "BEGIN":
                prev_token = "EXE"
                continue
            prev_token = "ARG"
            args.append(
                Argument(
                    name=m.group(1),
                    type=ArgumentType.DEFAULT,
                    type_name="",
                    default="",
                    required=not optional,
                    repeated=False,
                )
            )
        elif m := re.match(r"\s*\.\.\.", s):
            if prev_token not in ("ARG", "RBRACKET"):
                raise ValueError(f"Unexpected '...' after position {n}: {usage}")
            if not args:
                raise ValueError(
                    f"Args is still empty on '...' after position {n}: {usage}"
                )
            args[-1].repeated = True
            s = s[m.end() :]
            n += m.end()
            prev_token = "REPEATED"
        elif re.match(r"\s*$", s):
            break
        else:
            raise ValueError(f"Unexpected character {s[0]} at position {n}: {usage}")

    return usage, _finalize_arguments(args)


def _parse_func_comment(comment: list[str]) -> tuple[str, list[Argument], list[str]]:
    usage = "[ARG...]"
    args = []
    flags = []
    filtered_comment = []
    for line in comment:
        if m := re.match(r"Usage: (.+)", line, re.IGNORECASE):
            usage, args = _parse_usage(m.group(1))
        else:
            filtered_comment.append(line)

    if filtered_comment and not filtered_comment[-1]:
        filtered_comment.pop()
    if filtered_comment and not filtered_comment[0]:
        filtered_comment.pop(0)
    return usage, args, filtered_comment


def parse_module(lines: Iterable[str], package: str) -> Module:
    line_no = 1
    comment_no = 0
    last_comment_line: int | None = None
    comment_block: list[str] = []
    module = Module(name=package, functions=[], comment=[])
    for line in lines:
        # Functions are emitted right away. If there is a comment block ending
        # on the previous line, it's attached to the function.
        if match := _accept_fname(line):
            fname, span = match
            comment = comment_block if last_comment_line == line_no - 1 else []
            usage, args, comment = _parse_func_comment(comment)
            module.functions.append(
                Function(
                    name=Token(fname, (line_no, span[0]), (line_no, span[1])),
                    package=package,
                    comment=comment,
                    usage=usage,
                    args=args,
                )
            )
            comment_block = []
            comment_no += 1
        # Comment lines are accumulated. We keep the most recent block.
        elif (comment := _accept_comment(line)) is not None:
            if last_comment_line == line_no - 1:
                comment_block.append(comment)
            else:
                comment_block = [comment]
                comment_no += 1
            last_comment_line = line_no
        # The second comment block in a file is the module comment, unless it's
        # immediately followed by a function.
        elif comment_no == 2 and comment_block:
            module.comment = comment_block
            comment_block = []
        line_no += 1

    return module


def _local_name(func: str, module: str) -> str:
    if func.startswith(module + "_") and len(func) > len(module) + 1:
        return func[len(module) + 1 :]
    return func


def gen_switch(modules: Iterable[Module]) -> Generator[str, None, None]:
    yield "function __q() {"
    yield '  if [ "$#" -eq 0 ]; then'
    yield "    __q_help"
    yield "    return 0"
    yield "  fi"
    yield '  case "$1" in'
    yield "  help|-h|--help|?)"
    yield "    shift"
    yield '    __q_help "$@"'
    yield "    ;;"
    for module in modules:
        yield f"  {module.name})"
        yield f"    shift"
        yield f'    case "$1" in'
        yield f"    help|-h|--help|?)"
        yield f"      shift"
        yield f'      __q_help "{module.name}" "$@"'
        yield f"      ;;"
        for function in module.functions:
            if function.name.value.startswith("_"):
                continue
            aliases = [function.name.value]
            if (
                alias := _local_name(function.name.value, module.name)
            ) != function.name.value:
                aliases.append(alias)
            yield f'    {"|".join(aliases)})'
            yield f"      shift"
            yield f'      {function.name.value} "$@"'
            yield f"      ;;"
        yield f"    *)"
        yield f'      if [ -n "$1" ]; then'
        yield f'        echo "Module {module.name} has no function ${1}"'
        yield f"      fi"
        yield f"      __q_help {module.name}"
        yield f"      return 1"
        yield f"      ;;"
        yield f"    esac"
        yield f"    ;;"
    yield f"  *)"
    yield f'    echo "Unknown module ${1}"'
    yield f"    return 1"
    yield f"    ;;"
    yield f"  esac"
    yield "}"


def gen_help(modules: Iterable[Module]) -> Generator[str, None, None]:
    column = 18
    yield "function __q_help() {"
    yield '  if [ "$#" -eq 0 ]; then'
    yield '    echo "q - redshell function registry"'
    yield '    echo "Usage: q [-h|--help] MODULE FUNCTION [ARG...]"'
    yield '    echo "Run q --help MODULE for more information on a module."'
    yield "    echo"
    yield '    echo "Available modules:"'
    for module in modules:
        if not module.functions:
            continue
        doc = module.comment if module.comment else ["(no description)"]
        doc = list(_escape_comment(doc))
        pad = column - len(module.name) - 2
        if pad < 0:
            raise ValueError(
                f"Module name {module.name} is too long for the help output"
            )
        yield f"    echo '  {module.name}{" ":{pad}}{doc[0]}'"
        for line in doc[1:]:
            yield f"    echo '{" ":{column}}{line}'"
    yield "    return 0"
    yield "  fi"
    yield '  if [ "$#" -eq 1 ]; then'
    yield '    case "$1" in'
    for module in modules:
        yield f"    {module.name})"
        yield f'      echo "Usage: q {module.name} FUNCTION [ARG...]"'
        for line in module.comment:
            yield f'      echo "{line}"'
        yield f"      echo"
        yield f'      echo "Available functions:"'
        for function in module.functions:
            if function.name.value.startswith("_"):
                continue
            usage = function.usage
            if usage.startswith(function.name.value):
                usage = usage[len(function.name.value) :].strip()
            yield f"      tput bold"
            yield f'      echo "  q {module.name} {_local_name(function.name.value, module.name)} {usage}"'
            yield f"      tput sgr0"
            for line in _escape_comment(function.comment):
                yield f"      echo '    {line}'"
        yield f"      ;;"
    yield f"    *)"
    yield f'      echo "Unknown module $1"'
    yield f"      return 1"
    yield f"      ;;"
    yield f"    esac"
    yield f"  fi"
    yield "}"


def gen_bash_complete(modules: Iterable[Module]) -> Generator[str, None, None]:
    cword_offset = 2

    yield "function __q_compgen() {"
    yield f'  local modules="{" ".join(module.name for module in modules)}"'
    yield '  case "${COMP_CWORD}" in'

    # First argument is a module.
    yield "  1)"
    yield '    COMPREPLY=($(compgen -W "help ${modules}" -- ${COMP_WORDS[COMP_CWORD]}))'
    yield "    return 0"
    yield "  ;;"

    # Second argument is function in a module. (One case for each module).
    yield "  2)"
    yield '    case "${COMP_WORDS[1]}" in'
    for module in modules:
        yield f"    {module.name})"
        yield f'      COMPREPLY=($(compgen -W "help {" ".join(
            _local_name(function.name.value, module.name) for function in module.functions
            if not function.name.value.startswith("_")
        )}" -- ${{COMP_WORDS[COMP_CWORD]}}))'
        yield f"      return 0"
        yield f"      ;;"
    yield "    esac"
    yield "    ;;"

    # Remaining arguments are function arguments. At each position, we are
    # either recommending the name of the next --flag, or we are suggesting a
    # value for a positional argument or the previous --flag.
    #
    # Multiple of the below cases can be active at the same time. Their
    # suggestions are combined:
    #
    # 1. If CWORD=3 or the previous argument was a --flag of type SWITCH or a
    # positional argument, then we should suggest argument names.
    #
    # 2. If the previous argument was a --flag of type other than SWITCH or a
    # value for a repeated --flag argument of type other than SWITCH, then we
    # are suggesting values for that argument.
    #
    # 3. If there is a valid positional argument at this position, then we are
    # suggesting values for that argument. This is the most finnicky case.
    yield "  *)"
    yield '    local cur="${COMP_WORDS[COMP_CWORD]}"'
    yield '    local prev="${COMP_WORDS[COMP_CWORD-1]}"'
    yield '    case "${COMP_WORDS[1]}" in'
    for module in modules:
        if not [
            function
            for function in module.functions
            if not function.name.value.startswith("_")
        ]:
            continue
        yield f"    {module.name})"
        yield '      case "${COMP_WORDS[2]}" in'
        for function in module.functions:
            if function.name.value.startswith("_"):
                continue

            # The code to handle a particular function's arguments starts here.
            yield f"      {_local_name(function.name.value, module.name)})"
            # --flag names including aliases
            arg_names = []
            switch_names = []
            keyword_names = []
            repeated_names = []
            valid_positions = []
            for arg in function.args:
                if arg.position is not None:
                    valid_positions.append(arg.position + cword_offset)
                    continue
                arg_names.append(arg.name)
                arg_names.extend(arg.aliases)
                if arg.type == ArgumentType.SWITCH:
                    switch_names.append(arg.name)
                    switch_names.extend(arg.aliases)
                else:
                    keyword_names.append(arg.name)
                    keyword_names.extend(arg.aliases)
                if arg.repeated:
                    repeated_names.append(arg.name)
                    repeated_names.extend(arg.aliases)

            yield f'        local arg_names=({" ".join(arg_names)})'
            yield f'        local switch_names=({" ".join(switch_names)})'
            yield f'        local keyword_names=({" ".join(keyword_names)})'
            yield f'        local repeated_names=({" ".join(repeated_names)})'
            yield f'        local valid_positions=({" ".join(str(pos) for pos in valid_positions)})'
            yield f"        COMPREPLY=()"

            # Is a --flag name potentially valid here?
            yield f'        if [[ " ${{switch_names[@]}} " =~ " ${{prev}} " || "${{COMP_CWORD}}" == {cword_offset + 1} ]]; then'
            yield f'          COMPREPLY+=($(compgen -W "${{arg_names[*]}}" -- ${{cur}}))'
            yield f"        fi"

            # TODO: Currently these think every argument is a FILE.

            # Is a positional argument valid here?
            yield f'        if [[ " ${{valid_positions[@]}} " =~ " ${{COMP_CWORD}} " ]]; then'
            yield f"          COMPREPLY+=($(compgen -A file -- ${{COMP_WORDS[COMP_CWORD]}}))"
            yield f"        fi"

            # Is the previous argument a --flag expecting a value?
            yield f'        if [[ " ${{keyword_names[@]}} " =~ " ${{prev}} " ]]; then'
            yield f"          COMPREPLY+=($(compgen -A file -- ${{COMP_WORDS[COMP_CWORD]}}))"
            yield f"        fi"

            # TODO: Handle repeated

            yield f"        return 0"
            yield f"        ;;"
        yield f"      esac"
        yield f"      ;;"
    yield "    esac"
    yield "    ;;"
    yield "  esac"
    yield "}"
    yield ""
    yield "complete -F __q_compgen q"


def path_to_package(path: str, root: str) -> str:
    return path.removeprefix(root).removeprefix("/").removesuffix(".bash")


def load_modules(path: str) -> Generator[Module, None, None]:
    for root, _, files in os.walk(path):
        for file in files:
            if not file.endswith(".bash"):
                continue
            if ".gen." in file:
                continue
            with open(os.path.join(root, file), "r") as f:
                sys.stderr.write(f"Loading {os.path.join(root, file)}\n")
                yield parse_module(f, path_to_package(os.path.join(root, file), path))


def build_all(paths: list[str], output: str) -> None:
    modules = []
    sys.stderr.write(f"Building quick.gen.bash from {paths}\n")
    for path in paths:
        modules.extend(load_modules(path))

    gen_all(modules, output)


def gen_all(modules: list[Module], output: str) -> None:
    with open(output, "w") as f:
        f.write("# This file is generated by quick.py. Do not edit.\n")
        f.write("# Run q quick rebuild to regenerate.\n")
        f.write("\n")
        f.write(
            'if [[ -z "${_REDSHELL_GEN_QUICK}" || -n "${_REDSHELL_RELOAD}" ]]; then\n'
        )
        f.write("_REDSHELL_GEN_QUICK=1\n")
        for line in gen_switch(modules):
            f.write(line)
            f.write("\n")
        f.write("\n")
        for line in gen_help(modules):
            f.write(line)
            f.write("\n")
        f.write("\n")
        for line in gen_bash_complete(modules):
            f.write(line)
            f.write("\n")
        f.write("\n")
        f.write("fi\n")

    sys.stderr.write(f"Generated {output} with {len(modules)} modules\n")

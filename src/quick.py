# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# This script regenerates quick.gen.bash from the source files in src/. It's mostly
# a janky bash function parser that only handles the cases we use in this
# project.
#
# To regen quick.gen.bash on a system, just run `q quick rebuild`.
#
# To regenerate the checked-in version, run:
#
#  q quick rebuild --src-path ./src/ --skip-extra-paths

import os
import dataclasses
from dataclasses import dataclass
from typing import Iterable, Generator, Union
from enum import Enum
import re
import sys
import shlex


@dataclass
class Token:
    value: str
    start: tuple[int, int]
    end: tuple[int, int]

    @classmethod
    def from_dict(cls, d):
        return cls(
            value=d["value"],
            start=(d["start"]["line"], d["start"]["column"]),
            end=(d["end"]["line"], d["end"]["column"]),
        )


class ArgumentType(Enum):
    DEFAULT = 1
    SWITCH = 2
    FILE = 3
    DIRECTORY = 4
    STRING = 5
    USER = 7
    GROUP = 8
    HOSTNAME = 9


# ANSI escape codes for colors (256-color mode: \033[38;5;Nm)
ANSI_COLORS = {
    1: "\\033[31m",      # red
    2: "\\033[32m",      # green
    4: "\\033[34m",      # blue
    6: "\\033[36m",      # cyan
    9: "\\033[91m",      # bright red
    10: "\\033[92m",     # bright green
}
ANSI_BOLD = "\\033[1m"
ANSI_RESET = "\\033[0m"

ARG_TYPE_COLORS = {
    ArgumentType.DEFAULT: None,
    ArgumentType.SWITCH: None,
    ArgumentType.FILE: 9,
    ArgumentType.DIRECTORY: 1,
    ArgumentType.STRING: None,
    ArgumentType.USER: 10,
    ArgumentType.GROUP: 2,
    ArgumentType.HOSTNAME: 4,
}


@dataclass
class Argument:
    name: str
    type: ArgumentType
    type_name: str
    default: str
    required: bool = False
    repeated: bool = False
    position: Union[int, None] = None
    aliases: Iterable[str] = ()

    @classmethod
    def from_dict(cls, d):
        return cls(
            name=d["name"],
            type=ArgumentType[d["type"]],
            type_name=d["type_name"],
            default=d["default"],
            required=d["required"],
            repeated=d["repeated"],
            position=d["position"],
            aliases=d["aliases"],
        )


@dataclass
class Function:
    name: Token
    package: str
    comment: list[str]
    usage: str
    args: list[Argument]

    @classmethod
    def from_dict(cls, d):
        return cls(
            name=Token.from_dict(d["name"]),
            package=d["package"],
            comment=d["comment"],
            usage=d["usage"],
            args=[Argument.from_dict(a) for a in d["args"]],
        )


@dataclass
class Module:
    name: str
    functions: list[Function]
    func_to_alias: dict[str, list[str]]
    comment: list[str]

    def toJSON(self):
        return dataclasses.asdict(self)

    @classmethod
    def from_dict(cls, d):
        return cls(
            name=d["name"],
            functions=[Function.from_dict(f) for f in d["functions"]],
            func_to_alias=d["aliases"],
            comment=d["comment"],
        )


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


# Returns the function name and its position in the line, or None.
def _accept_fname(line: str) -> Union[tuple[str, tuple[int, int]], None]:
    # Bash supports two variants of declaration syntax:
    # Type A: fname () compound-command [ redirections ]
    # Type B: function fname [()] compound-command [ redirections ]

    if m := FNAME_TYPE_A.match(line):
        return m.group(1), m.span(1)
    elif m := FNAME_TYPE_B.match(line):
        return m.group(1), m.span(1)
    else:
        return None

def _accept_alias(line: str) -> Union[tuple[str, str], None]:
    if line.startswith("alias "):
        parts = line[6:].split("=", 1)
        return parts[0].strip(), parts[1].strip()
    else:
        return None


def _accept_comment(line: str) -> Union[str, None]:
    if line.startswith("#"):
        return line[1:].strip()
    else:
        return None


def _parse_arg_type(s: str) -> ArgumentType:
    if "file" in s.lower() or "path" in s.lower():
        return ArgumentType.FILE
    if "dir" in s.lower() or "directory" in s.lower():
        return ArgumentType.DIRECTORY
    if "user" in s.lower():
        return ArgumentType.USER
    if "group" in s.lower():
        return ArgumentType.GROUP
    if "host" in s.lower() or "hostname" in s.lower():
        return ArgumentType.HOSTNAME
    if "string" in s.lower():
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
                arg.type = _parse_arg_type(arg.name)

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
        elif re.match(r"[\s\.]*$", s):
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
    last_comment_line: Union[int, None] = None
    comment_block: list[str] = []
    module = Module(name=package, functions=[], func_to_alias={}, comment=[])
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
        elif alias := _accept_alias(line):
            comment_block = []
            comment_no += 1
            module.func_to_alias.setdefault(alias[1], []).append(alias[0])
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
    yield "  dump)"
    yield "    shift"
    yield '    __q_dump "$@"'
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


def __gen_usage_color(function: Function) -> Iterable[Union[str,int]]:
    for arg in function.args:
        if not arg.required:
            yield '['
        color = ARG_TYPE_COLORS.get(arg.type, None)

        # Only highlight the upper case TYPE NAME. If the type name is set, then
        # we're on a --flag TYPE argument and don't want to highlight the --flag
        # part.
        if not arg.type_name and color is not None:
            yield color
        yield "|".join([arg.name] + list(arg.aliases))
        if arg.type_name:
            if color is not None:
                yield color
            yield arg.type_name
        
        if arg.repeated:
            yield "..."
        
        if not arg.required:
            yield ']'

def gen_dump(modules: Iterable[Module]) -> Generator[str, None, None]:
    yield "function __q_dump() {"
    yield '  if [[ ! "$#" -eq 2 ]]; then'
    yield '    echo "Usage: q dump MODULE FUNCTION"'
    yield "    return 1"
    yield "  fi"
    yield "  case \"$1\" in"
    for module in modules:
        yield f"  {module.name})"
        yield f'    case \"$2\" in'
        for function in module.functions:
            yield f"    {_local_name(function.name.value, module.name)})"
            yield f"      type {function.name.value}"
            yield f"      ;;"
        yield f"    *)"
        yield f'      echo "Unknown function $2"'
        yield f"      return 1"
        yield f"      ;;"
        yield f"    esac"
        yield f"    ;;"
    yield f"  *)"
    yield f'    echo "Unknown module $1"'
    yield f"    return 1"
    yield f"    ;;"
    yield "  esac"
    yield "}"


def gen_help(modules: Iterable[Module]) -> Generator[str, None, None]:
    column = 20
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
        yield f"    echo -ne '{ANSI_BOLD}'"
        yield f"    echo -n '  {module.name}'"
        yield f"    echo -ne '{ANSI_RESET}'"
        yield f"    echo '{' ' * pad}{doc[0]}'"
        for line in doc[1:]:
            yield f"    echo '{' ' * column}{line}'"
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

            # Usage
            yield f"      echo -ne '{ANSI_BOLD}'"
            yield f"      echo -n '  {_local_name(function.name.value, module.name)}'"
            for s in __gen_usage_color(function):
                if isinstance(s, int):
                    yield f"      echo -ne '{ANSI_COLORS[s]}'"
                else:
                    yield f"      echo -n ' {s}'"
                    yield f"      echo -ne '{ANSI_RESET}'"
                    yield f"      echo -ne '{ANSI_BOLD}'"
            yield f"      echo"
            yield f"      echo -ne '{ANSI_RESET}'"

            # Aliases
            yield f"      echo -ne '{ANSI_COLORS[6]}'"
            for alias in module.func_to_alias.get(function.name.value, []):
                yield f'      echo "    alias {alias}=\'q {module.name} {_local_name(function.name.value, module.name)}\'"'
            yield f"      echo -ne '{ANSI_RESET}'"

            # Description
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


def gen_complete_helpers() -> Generator[str, None, None]:
    """Generate helper functions for bash completion."""
    # Helper to complete values based on type
    yield "# Complete a value based on its type."
    yield "# Usage: __q_complete_type TYPE CUR"
    yield "function __q_complete_type() {"
    yield '  local type="$1" cur="$2"'
    yield '  case "${type}" in'
    yield "  FILE)"
    yield '    COMPREPLY+=($(compgen -A file -- "${cur}"))'
    yield "    ;;"
    yield "  DIRECTORY)"
    yield '    COMPREPLY+=($(compgen -A directory -- "${cur}"))'
    yield "    ;;"
    yield "  USER)"
    yield '    COMPREPLY+=($(compgen -A user -- "${cur}"))'
    yield "    ;;"
    yield "  GROUP)"
    yield '    COMPREPLY+=($(compgen -A group -- "${cur}"))'
    yield "    ;;"
    yield "  HOSTNAME)"
    yield '    COMPREPLY+=($(compgen -A hostname -- "${cur}"))'
    yield '    if [[ -f ~/.ssh/config ]]; then'
    yield "      COMPREPLY+=($(compgen -W \"$(grep -i '^Host ' ~/.ssh/config 2>/dev/null | awk '{print $2}' | grep -v '[*?]')\" -- \"${cur}\"))"
    yield "    fi"
    yield "    ;;"
    yield "  STRING|DEFAULT)"
    yield "    ;;"
    yield "  *)"
    yield '    COMPREPLY+=($(compgen -A file -- "${cur}"))'
    yield "    ;;"
    yield "  esac"
    yield "}"
    yield ""
    # Main completion helper - walks args and determines what to complete
    yield "# Complete function arguments by walking COMP_WORDS to determine state."
    yield "#"
    yield "# At each position, we either suggest the name of the next --flag, or a"
    yield "# value for a positional argument or the previous --flag. Multiple cases"
    yield "# can be active at the same time; their suggestions are combined:"
    yield "#"
    yield "# 1. If CWORD=3 or the previous word was a SWITCH or a positional value,"
    yield "#    we are in EXPECT_ARG state and should suggest flag names."
    yield "#"
    yield "# 2. If the previous word was a KEYWORD (flag that takes a value), we are"
    yield "#    in EXPECT_VALUE state and should suggest values of the keyword's type."
    yield "#"
    yield "# 3. If there is a positional argument at the current position, we also"
    yield "#    suggest values for that argument (combined with flag names from #1)."
    yield "#"
    yield "# Usage: __q_complete_func SWITCHES KEYWORDS KEYWORD_TYPES POSITIONAL_TYPES"
    yield "#   SWITCHES: space-separated switch names (flags that take no value)"
    yield "#   KEYWORDS: space-separated keyword names (flags that take a value)"
    yield "#   KEYWORD_TYPES: colon-separated name:TYPE pairs for keywords"
    yield "#   POSITIONAL_TYPES: space-separated types for positional args"
    yield "function __q_complete_func() {"
    yield '  local switches="$1" keywords="$2" keyword_types="$3" positional_types_str="$4"'
    yield '  local cur="${COMP_WORDS[COMP_CWORD]}"'
    yield "  local i=3 pos=0 state=EXPECT_ARG"
    yield "  local -a positional_types=(${positional_types_str})"
    yield ""
    yield "  # Walk through previous args to determine current state"
    yield '  while [[ "${i}" -lt "${COMP_CWORD}" ]]; do'
    yield '    local word="${COMP_WORDS[i]}"'
    yield '    case "${state}" in'
    yield "    EXPECT_ARG)"
    yield '      if [[ "${word}" == "--" ]]; then'
    yield "        state=IDK"
    yield '      elif [[ " ${keywords} " == *" ${word} "* ]]; then'
    yield "        # This is a keyword arg, next word is its value"
    yield "        local ktype"
    yield '        for pair in ${keyword_types}; do'
    yield '          if [[ "${pair%%:*}" == "${word}" ]]; then'
    yield '            ktype="${pair#*:}"'
    yield "            break"
    yield "          fi"
    yield "        done"
    yield '        state="EXPECT_VALUE_${ktype:-STRING}"'
    yield '      elif [[ " ${switches} " == *" ${word} "* ]]; then'
    yield "        state=EXPECT_ARG"
    yield '      elif [[ "${word}" != -* ]]; then'
    yield "        # Positional argument consumed"
    yield "        (( pos++ ))"
    yield "        state=EXPECT_ARG"
    yield "      else"
    yield "        state=EXPECT_ARG"
    yield "      fi"
    yield "      ;;"
    yield "    EXPECT_VALUE_*)"
    yield "      # Value consumed, back to expecting args"
    yield "      state=EXPECT_ARG"
    yield "      ;;"
    yield "    IDK)"
    yield "      break"
    yield "      ;;"
    yield "    esac"
    yield "    (( i++ ))"
    yield "  done"
    yield ""
    yield "  COMPREPLY=()"
    yield '  case "${state}" in'
    yield "  EXPECT_ARG)"
    yield "    # Suggest switches and keywords"
    yield '    COMPREPLY+=($(compgen -W "${switches} ${keywords}" -- "${cur}"))'
    yield "    # Also complete positional arg if available"
    yield '    if [[ -n "${positional_types[$pos]}" ]]; then'
    yield '      __q_complete_type "${positional_types[$pos]}" "${cur}"'
    yield "    fi"
    yield "    ;;"
    yield "  EXPECT_VALUE_*)"
    yield '    __q_complete_type "${state#EXPECT_VALUE_}" "${cur}"'
    yield "    ;;"
    yield "  IDK)"
    yield '    COMPREPLY+=($(compgen -W "${switches} ${keywords}" -- "${cur}"))'
    yield '    COMPREPLY+=($(compgen -A file -- "${cur}"))'
    yield "    ;;"
    yield "  esac"
    yield "}"
    yield ""


def _build_func_completion_data(function: Function) -> tuple[str, str, str, str]:
    """Build completion data strings for a function.

    Returns: (switches, keywords, keyword_types, positional_types)
    """
    switches = []
    keywords = []
    keyword_types = []  # "name:TYPE" pairs
    positional_types = []

    for arg in function.args:
        if arg.position is not None:
            positional_types.append(arg.type.name)
        elif arg.type == ArgumentType.SWITCH:
            switches.append(arg.name)
            switches.extend(arg.aliases)
        else:
            keywords.append(arg.name)
            keywords.extend(arg.aliases)
            keyword_types.append(f"{arg.name}:{arg.type.name}")
            for alias in arg.aliases:
                keyword_types.append(f"{alias}:{arg.type.name}")

    return (
        " ".join(switches),
        " ".join(keywords),
        " ".join(keyword_types),
        " ".join(positional_types),
    )


def gen_bash_complete(modules: Iterable[Module]) -> Generator[str, None, None]:
    # First, emit the helper functions
    yield from gen_complete_helpers()

    yield "function __q_compgen() {"
    yield f'  local modules="{" ".join(module.name for module in modules)}"'
    yield '  case "${COMP_CWORD}" in'

    # First argument is a module.
    yield "  1)"
    yield '    COMPREPLY=($(compgen -W "help ${modules}" -- ${COMP_WORDS[COMP_CWORD]}))'
    yield "    return 0"
    yield "  ;;"

    # Second argument is function in a module.
    yield "  2)"
    yield '    case "${COMP_WORDS[1]}" in'
    for module in modules:
        yield f"    {module.name})"
        names = " ".join(
            _local_name(function.name.value, module.name)
            for function in module.functions
            if not function.name.value.startswith("_")
        )
        yield f'      COMPREPLY=($(compgen -W "help {names}" -- ${{COMP_WORDS[COMP_CWORD]}}))'
        yield f"      return 0"
        yield f"      ;;"
    yield "    esac"
    yield "    ;;"

    # Remaining arguments - delegate to helper
    yield "  *)"
    yield '    case "${COMP_WORDS[1]}" in'
    for module in modules:
        public_funcs = [f for f in module.functions if not f.name.value.startswith("_")]
        if not public_funcs:
            continue
        yield f"    {module.name})"
        yield '      case "${COMP_WORDS[2]}" in'
        for function in public_funcs:
            local_name = _local_name(function.name.value, module.name)
            switches, keywords, keyword_types, positional_types = _build_func_completion_data(function)
            yield f"      {local_name})"
            yield f'        __q_complete_func "{switches}" "{keywords}" "{keyword_types}" "{positional_types}"'
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
        for line in gen_dump(modules):
            f.write(line)
            f.write("\n")
        f.write("\n")
        for line in gen_bash_complete(modules):
            f.write(line)
            f.write("\n")
        f.write("\n")
        f.write("fi\n")

    sys.stderr.write(f"Generated {output} with {len(modules)} modules\n")


def build_all(paths: list[str], output: str) -> None:
    modules = []
    sys.stderr.write(f"Building quick.gen.bash from {paths}\n")
    for path in paths:
        modules.extend(load_modules(path))

    modules.sort(key=lambda m: m.name)

    gen_all(modules, output)

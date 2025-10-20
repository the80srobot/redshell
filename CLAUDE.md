# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Redshell is a personal collection of bash functions and utilities organized into a modular system. Functions are grouped into modules (`.bash` files in `src/`) and accessed via the `q` command-line interface. The system auto-generates help text, tab completion, and function dispatch from specially-formatted comments in bash source files.

**Key principle**: This is a personal utility collection. Code quality varies, nothing is guaranteed to work everywhere, and macOS (with bash) is the primary target platform.

## Installation & Setup

- **Install redshell**: Run `./setup.sh` from the repository root
  - This copies files to `~/.redshell/` and installs `~/.bash_profile`
  - On macOS, it switches the shell to bash and installs a current bash version via Homebrew
  - Creates persistent storage in `~/.redshell_persist/`

- **After installation**, the `q` command becomes available in new shells

## Core Architecture

### Module System

Each `.bash` file in `src/` is a module containing related functions:
- Module names come from filenames: `src/git.bash` → `git` module
- Functions follow naming convention: `module_function` (e.g., `git_info`)
- Functions are called via: `q MODULE FUNCTION [ARGS...]` or `q MODULE FUNCTION_SUFFIX [ARGS...]`

### The `q` Command

The `q` command is the primary interface to all redshell functions:
- `q` - Show all available modules and their descriptions
- `q MODULE` - Show all functions in a module
- `q MODULE FUNCTION [ARGS...]` - Call a specific function
- `q dump MODULE FUNCTION` - Show the source code of a function

Examples:
```bash
q                          # List all modules
q git                      # List all git functions
q git info                 # Call git_info function
q net ip4                  # Call net_ip4 function
```

### Auto-Generated Code

The `quick.py` Python script parses all `.bash` files and generates `quick.gen.bash`, which contains:
- The `__q()` function (main dispatch/switch)
- Help text (`__q_help()`)
- Tab completion (`__q_compgen()`)
- Function dumper (`__q_dump()`)

**To regenerate** after editing functions:
```bash
q quick rebuild                                    # Rebuild from installed location (~/.redshell/src)
q quick rebuild --src-path ./src --skip-extra-paths  # Rebuild for check-in (from repo)
```

### Function Documentation Format

Functions must follow this format for `quick.py` to parse them correctly:

```bash
# Function description goes here.
# Can span multiple lines.
# Usage: function_name [--flag] REQUIRED_ARG [OPTIONAL_ARG]
function module_function_name() {
    # implementation
}
```

**Important parsing rules**:
- The `Usage:` line defines arguments and their types
- Arguments in `[brackets]` are optional
- Arguments followed by `...` are repeated
- Argument type is inferred from the name:
  - `FILE` or `PATH` → file completion
  - `DIR` or `DIRECTORY` → directory completion
  - `USER` → user completion
  - `HOST` or `HOSTNAME` → hostname completion
  - `--flag` alone → boolean switch
  - `--flag TYPE` → flag with typed value

### Module Structure Pattern

Each `.bash` module follows this pattern:

```bash
# SPDX-License-Identifier: Apache-2.0
# Copyright (c) 2024 Adam Sindelar

# Module description (second comment block becomes module help text)

source "dependency.bash"  # Source other modules if needed

if [[ -z "${_REDSHELL_MODULE}" || -n "${_REDSHELL_RELOAD}" ]]; then
_REDSHELL_MODULE=1

# Functions go here...

fi # _REDSHELL_MODULE
```

The `if` guard prevents multiple sourcing (important since modules source each other).

## Key Modules

- **quick** - The function registry and dispatch system
- **init** - Shell initialization, aliases, editor setup
- **mac** - macOS-specific setup and Homebrew integration
- **install** - File installation with guarded sections (used by setup.sh)
- **python** - Python virtualenv management and bash-python FFI
- **notes** - Git-based markdown note management
- **net** - Network utilities (IP addresses, WiFi info)
- **git** - Git helpers and prompt widgets
- **crypt** - Encryption, SSH, GPG helpers
- **file** - File manipulation utilities
- **path** - Path manipulation and expansion

## Python Integration

Some modules include `.py` files alongside `.bash` files:
- `quick.py` - Parses bash modules and generates dispatch code
- `net.py` - Network helper functions
- Python code is typically invoked via `python_func` from `python.bash`

## Development Workflow

1. **Edit a function**: Modify a `.bash` file in `src/`
2. **Test locally**: Source the file or reload your shell
3. **Regenerate quick.gen.bash**: Run `q quick rebuild --src-path ./src --skip-extra-paths`
4. **Commit changes**: Both the source `.bash` file AND `quick.gen.bash` must be committed

## Common Tasks

### Adding a new function

1. Open the appropriate module in `src/` (or create a new one)
2. Add your function with proper comment format including `Usage:` line
3. Regenerate: `q quick rebuild --src-path ./src --skip-extra-paths`
4. Test: `q MODULE FUNCTION`

### Adding a new module

1. Create `src/yourmodule.bash` following the module structure pattern
2. Add module description as the second comment block
3. Add functions with proper documentation
4. Regenerate: `q quick rebuild --src-path ./src --skip-extra-paths`

### Debugging the parser

If `quick.py` fails to parse your function:
- Check the `Usage:` line format matches expected patterns
- Verify function declaration uses `function name()` or `name() ` syntax
- Ensure argument names match recognized types (FILE, PATH, DIR, etc.)
- Run `python3 src/quick.py` directly to see parsing errors

## Platform-Specific Code

- **macOS**: `mac.bash` handles macOS-specific setup, Homebrew, shell switching
- **Debian/Ubuntu**: `debian.bash` contains apt-based setup
- **Fedora**: `fedora.bash` contains dnf-based setup

Platform detection uses `uname -a` pattern matching in conditionals.

## File Locations

- **Source**: `~/code/redshell/src/` (or wherever repo is cloned)
- **Installed**: `~/.redshell/src/` (copied by setup.sh)
- **Config**: `~/.bash_profile` (installed by setup.sh)
- **Persistent data**: `~/.redshell_persist/`
- **Visual identity**: `~/.redshell_visual` (ASCII art character for prompt)

## Important Notes

- **Bash only** - This does not work with zsh, fish, or other shells
- **No test suite** - Functions are tested manually
- **Quick rebuild required** - After editing function signatures or usage, you must rebuild `quick.gen.bash`
- **Both files must be committed** - Always commit both the source `.bash` file and regenerated `quick.gen.bash`

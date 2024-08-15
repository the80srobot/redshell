# Adam's Emporium of Janky Bash Functions

This repo contains a collection of bash functions I've found useful over the
years. The quality massively varies, and nothing is guaranteed to work
everywhere.

It's probably best if nobody uses this for anything.

**WARNING:** running `setup.sh` will make opinionated changes to your computer,
which you might not like. Proceed at your own risk.

The collection is (mostly) self-documented. After installing (with `setup.sh`),
new shells will have access to the function switch `q`:

```
> q
q - redshell function registry
Usage: q [-h|--help] MODULE FUNCTION [ARG...]
Run q --help MODULE for more information on a module.

Available modules:
  ascii_art         Assorted ascii art, screen drawing and speech bubbles.
  bash              Parse bash files and automate bash scripting.
  browser           Browser automation, downloads, link generators.
  crypt             Encrypt/decrypt, signing, keypairs. SSH and GPG helpers.

...
```

## What about zsh, fish, etc?

You can try, but it probably won't work. On macOS, `setup.sh` will switch your
shell back to `bash`, and even install a current version of `bash`, so you don't
need to worry about `zsh` unless you really want to.

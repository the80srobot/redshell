# Security Review Checklist

This is an incomplete, non-exhaustive list of common security issues:

- [ ] Privilege escalation paths
- [ ] Code runs at the wrong privilege level (too high)
- [ ] Implicit trust
- [ ] User input used without validation
- [ ] Missing bounds checks for arrays and interfaces (e.g. ioctls, C arrays...)
- [ ] Files and sockets created with improper permissions (e.g. via umask)

## Rust specific

- [ ] Use of `unsafe` without proper safety comments

## eBPF Specific

- [ ] TOCTOU issues

# Performance Review Checklist

This is an incomplete, non-exhaustive list of common performance problems.

- [ ] Random access when sequential scan is possible
- [ ] Too many heap allocations
- [ ] Allocation in a loop
- [ ] Array reallocation in a builder pattern

## Rust-specific

- [ ] Unnecessary `Arc` or atomics
- [ ] Reference counting or runtime borrow checking to get around the borrow checker

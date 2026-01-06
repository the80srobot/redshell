# Common Bugs Review Checklist

This is an incomplete, non-exhaustive list of common bugs.

## Logic Errors

- [ ] Off-by-one errors in loops and array access
- [ ] Incorrect boolean logic (De Morgan's law violations)
- [ ] Missing null/undefined checks
- [ ] Race conditions in concurrent code
- [ ] Integer overflow/underflow
- [ ] Floating point comparison issues

## Error Handling

- [ ] Unchecked errors and exceptions

## Rust Specific

- [ ] Most `unwrap` calls. Use `Result` for runtime errors, `expect` for programmer errors, unless very obvious.

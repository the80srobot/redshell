---
name: local-code-review
description: Review the code and run quick checks.
allowed-tools: [
    "Bash(${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh:*)",
    "Read",
    "Skill",
    "TodoWrite",
    "Grep",
    "Glob",
]
---

# Local Code Review

Provides code review for code on a **local** branch or a range of commits. Not intended for PR review.

## When to Use This Skill

- When requested
- After making extensive changes, adding new modules or features, atfer confirming with the user

## Instructions

Follow these steps precisely:

1. Launch a haiku agent to return a list of file paths (not contents) for all relevant CLAUDE.md files.

2. Launch a haiku agent to generate a reviewable diff, using `${CLAUDE_PLUGIN_ROOT}/scripts/diff.sh`.

3. Launch a sonnet agent to view the diff and commit messages and generate a summary of the changes.

4. Launch 3 agents in parallel to independently review the changes. Each agent should return a list of issues, with each issue including a description, the reason it was flagged and confidence. The agents should do the following:

Agent 1: CLAUDE.md compliance sonnet agent
Audit changes for CLAUDE.md compliance. Only consider CLAUDE.md files that share a path with the file under review.

Agent 2: Opus bug agent (parallel with agent 3)
Scan for bugs. Focus only on the diff itself without reading extra context. Flag only significant bugs; ignore nitpicks and likely false positives. Do not flag issues that you cannot validate without looking at contet outside of the git diff.

Agent 3: Opus bug agent (parallel with agent 2)
Look for problems that exist in the introduced code. Include security issues, incorrect logic, etc. Only look for issues that are related to the changed code. Consult non-exhaustive checklists in `reference/`, but do not be limited by them.

**Important: We only want high-signal issues.** This means:

- Catch bugs and edge cases
- Prevent unnecessary complexity
- Prevent unnecessary dependencies
- Solve the right problem at hand
- Ensure maintainability and readability
- Enforce standards
- Ensure the code is as simple as possible
- Reduce verbosity
- Remove spurious, overly verbose or redundant comments

**We specifically do not want:**

- Unnecessary nitpicking, or pushing personal preferences
- Block progress
- Nitpick formatting (use linters)
- Demand 100% test coverage. We must be measured.
- Adding comments and docstrings on everything
- Potential issues that "might" become problems

In addition to the above, each subagent should be told the change summary to communicate author intent and important context.

5. For each issue found in the previous step by agents 2 and 3, launch parallel subagents to validate the issue. These subagents should get the change summary and a description of the issue. The agent's job is to review the issue and validate that the stated issue is real and significant. For example,  if an issue such as "variable is not defined", then the subagent's job would be to validate that is actually true in the code. Use Opus agents for bugs and logic issues and Sonnet agents for CLAUDE.md violations.

6. Filter out any issues that were not validated in step 5. This will give us the final list of high-signal issues for review.

7. Present the user with a summary. For each issue include:
   - `path`: The file path
   - `lines`: The buggy line or lines so the the user sees them
   - `body`: Description of the issue. For small fixes, include a suggestion with corrected code.

## Review Techniques

Key questions:
- Does the behavior of functions, types and modules match their documentation?
- Does the code reinvent the wheel, problems solved elsewhere?
- Does the change introduce any heavy dependencies?
- Is the code as simple as possible?
- Is the code easy to understand, and is the behavior obvious?
- Are comments helpful, or do they just add clutter?
- Do comments explain the *why* rather than the *what*?

Effective feedback is:
- Specific
- Brief
- Targeted

## Checklists

Use non-exhaustive checklists for consistency and thoroughness. They include:
- [Security Checklist](reference/security-checklist.md)
- [Common Bugs](reference/common-bugs-checklist.md)
- [Comments Checklist](reference/comments-checklist.md)
- [Performance Issues](reference/performance-checklist.md)

**Important:** The checklists are not complete. They point out common issues, but are not a replacement for a thorough review.

## Utility Scripts

- **`diff.sh`** - Show diff of code under review.
  - No args: diffs current branch against master
  - Single commit (e.g., `abc123`): shows that commit's changes
  - Range (e.g., `abc123..def456`): shows changes in that range
  - Multiple args: processes each in sequence

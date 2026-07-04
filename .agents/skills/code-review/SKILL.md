---
name: "code-review"
description: "Perform a review of the changes in this directory/worktree/branch/PR."
---

# Code Review

- Please instruct a subagent to perform a rigorous review of the changes we've made here.
- Give the subagent a bit of context about what we're working on here.
- Do feel free to specifically instruct the subagent to take an adversarial stance, or even do full-on red-teaming, depending on the nature of the changes.

## What to review

- If we are in a PR, all changes in the PR should be reviewed.
- If we are in a branch that has not been posted as a PR, all changes in the branch (vs. its upstream branch) should be reviewed.
- If there are any uncommitted changes, include them in the review.

## How to report

- Report your findings as a numbered list, categorized as "critical", "high", "medium" and "low".
- Each item should be Markdown formatted, with a heading stating a unique ID, the finding level, and a summary, eg. `## 1. CRITICAL: Permissions are not being evaluated`
- For each item, explain your finding, and its potential consequences.
- Please only include your findings. Don't specifically mention if you had no findings.

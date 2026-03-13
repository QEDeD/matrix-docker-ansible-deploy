<!--
SPDX-FileCopyrightText: 2026 MDAD project contributors

SPDX-License-Identifier: AGPL-3.0-or-later
-->

# Upstream Role Contribution Workflow

## Purpose

- Optimize upstream role PRs and new-role creation for mergeability, not just
  correctness.
- Treat merged sibling-role patterns and maintainer intent as first-class
  inputs.

## Required Pre-Change Review

- Inspect the current implementation and surrounding role behavior.
- Inspect merged sibling-role implementations for similar changes or hardening.
- Inspect git history and relevant PR discussion.
- Use `code-review-intention-v1` when the code or surrounding behavior is not
  already well understood.

## Branch and Base Rules

- Upstream contribution branches must start from `upstream/<default>` or a
  clean `upstreamable/*` branch rebased onto it.
- Do not base upstream PR work on fork-maintenance branches that carry
  support-file deltas.
- These fork-tracked support paths are not automatically upstreamable:
  - `AGENTS.md`
  - `docs/ai/**`
  - `.codex/**`
  - `local-notes/**`
  - `plans/**`
- If the diff against `upstream/<default>` includes those paths without
  explicit intent, rebuild the branch from `upstream/<default>` and reapply
  only upstream-intended commits.

## Existing-Role PR Workflow

- Keep scope tight.
- Avoid unrelated lint, formatting, or variable-migration churn unless it is
  trivial and clearly justified.
- Prefer already accepted sibling-role shaping over one-off local
  implementations.
- Reduce the final review branch to one coherent commit unless a multi-commit
  series is clearly better for review.
- Ensure the PR title and body describe the exact final diff.

## New-Role Creation Workflow

- Study sibling roles before designing defaults, templates, docs, or
  validation.
- Align role structure, docs, validation, and variable naming with the current
  role ecosystem style.
- Stabilize the role shape first, then wire it into the playbook in a separate
  step or clearly separated commit series.

## Refresh and Superseded PR Workflow

- If the implementation changes materially after review starts, refresh the PR
  body and add a short comment.
- If equivalent work lands upstream, close the PR and reference the superseding
  commit.
- When refreshing an existing PR, re-check current upstream before push.

## Pre-Push Checks

- `behind=0` vs `upstream/<default>`
- changed files are exactly intended
- support-path contamination check passes
- lint status is accurate and scoped
- final branch history matches the intended review shape
- PR body/comment alignment is re-checked after rebases, squashes, or
  force-pushes

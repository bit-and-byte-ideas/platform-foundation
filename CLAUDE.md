# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

An OpenTofu project for managing cloud infrastructure, with a primary focus on Azure. This is a modular IaC framework — modules define reusable components, stacks compose them into deployable configurations.

## Common Commands

```bash
# Initialize a working directory (run from a stack or module directory)
tofu init

# Preview changes
tofu plan

# Apply changes
tofu apply

# Validate HCL syntax
tofu validate

# Format HCL files
tofu fmt -recursive
```

## Architecture

The project follows a three-layer structure:

- **`modules/`** — Reusable, composable infrastructure building blocks
  - `modules/azure/` — Azure-specific resource modules
  - `modules/common/` — Cloud-agnostic shared modules
- **`stacks/`** — Top-level deployment configurations that compose modules into complete environments
  - `stacks/azure/` — Azure deployments
- **`policies/`** — Infrastructure policy and compliance definitions (e.g., OPA or Sentinel rules)

Stacks reference modules via local paths or a registry. Variables and secrets are passed via `.tfvars` files (excluded from git via `.gitignore`).

## Notes

- State files (`*.tfstate`) and variable files (`*.tfvars`) are gitignored — never commit them.
- The `.terraform/` local working directory is also gitignored.

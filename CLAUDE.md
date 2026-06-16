# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo is the single source of truth for the SpendSense API contract. All proto files live under `spendsense/v1/`. Changes pushed to `main` are automatically published to the Buf Schema Registry at `buf.build/xpendsense/spendsense` via CI, which the backend consumes via `make generate`.

## Commands

```bash
buf lint          # lint all proto files
buf breaking --against .git#branch=main   # check for breaking changes vs main
```

## Proto files

| File | Service / types |
|---|---|
| `common.proto` | Shared types: `Money`, `RecurringType`, `ExpenseType`, `PaymentType` |
| `auth.proto` | `AuthService` — Register, Login, Logout, RefreshToken, Google OAuth |
| `user.proto` | `UserService` — GetMe, UpdateMe, ChangePassword, DeleteMe |
| `budget.proto` | `BudgetService` — budget CRUD, people, income entries, transactions, categories, payment methods |

## Adding an RPC

1. Add the RPC to the relevant `.proto` file's service block
2. Add request/response message types in the same file
3. Run `buf lint` — fix any issues before pushing
4. Push to `main` — CI runs breaking change detection, then publishes to BSR
5. In the backend: `make generate` to pull updated Go types, then implement the handler

## Breaking changes

CI uses `buf breaking` with `FILE` rules. Renaming fields, changing field numbers, or removing RPCs will fail the check. To intentionally make a breaking change, update the proto version (`v2/`) rather than modifying `v1/`.

## go_package

All proto files use:
```protobuf
option go_package = "github.com/mauro-afa91/spendsense/gen/spendsense/v1;spendsensev1";
```

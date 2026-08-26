# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

This repo is the single source of truth for the WellSpent API contract. All proto files live under `wellspent/v1/`. Changes pushed to `main` are automatically published to the Buf Schema Registry at `buf.build/bewellspent/wellspent` via CI, which the backend consumes via `make generate`.

There is a **second, parallel contract** in `openapi/v1/` covering a small set of
endpoints served as plain cacheable HTTP instead of Connect. It is not a
replacement and not a migration path — read `openapi/README.md` before adding
anything to it, especially the two-part test for what qualifies.

## Commands

```bash
make lint         # everything CI runs: buf lint + format check + OpenAPI lint
make format       # auto-fix proto formatting in place

buf lint          # proto only
buf breaking --against .git#branch=main   # check for breaking changes vs main
npx --yes @redocly/cli@1.34.1 lint        # OpenAPI only
```

## Proto files

| File | Service / types |
|---|---|
| `common.proto` | Shared types: `Money`, `RecurringType`, `ExpenseType`, `PaymentType`, `BudgetRole` |
| `auth.proto` | `AuthService` — Register, Login, Logout, RefreshToken, Google OAuth |
| `user.proto` | `UserService` — GetMe, UpdateMe, ChangePassword, DeleteMe |
| `budget.proto` | `BudgetService` — budget CRUD, people, income entries, transactions, categories, payment methods |
| `invite.proto` | `InviteService` — SendBudgetInvite, ListBudgetInvites, CancelBudgetInvite, GetBudgetInvite, AcceptBudgetInvite |

## OpenAPI contracts (`openapi/v1/`)

An endpoint belongs here only if it is **both** global (identical response for
every caller) **and** rarely-changing. Everything else — every personalized read
and every mutation without exception — stays on Connect. `openapi/README.md`
carries the full rule, the current endpoint list, and the candidates that were
considered and rejected.

Three things that are easy to get wrong:

- **It is OpenAPI 3.0.3, not 3.1**, because `oapi-codegen`'s kin-openapi base has
  incomplete 3.1 support while the web and iOS generators handle both.
- **It does not go through BSR.** There is no OpenAPI equivalent. This repo is
  public, so consumers fetch the raw file over HTTPS at codegen time.
- **It is hand-authored**, reviewed in PRs like the `.proto` files — never
  generated from Go handler annotations.

Retiring a Connect RPC in favour of a REST endpoint means deleting the RPC *and*
its request/response messages, leaving a comment on the service explaining where
it went. Shared messages (`StatusBanner`, `ChangelogRelease`) stay if other RPCs
still use them.

## Adding an RPC

1. Add the RPC to the relevant `.proto` file's service block
2. Add request/response message types in the same file
3. Run `buf lint` — fix any issues before committing
4. Commit, push to `develop`, create a PR to `main`, and enable auto-merge (see Git workflow below)
5. Once the PR merges, CI publishes to BSR — then run `make generate` in the backend to pull updated Go types

## Git workflow

`main` is production. Never commit or push directly to `main`. Pushing to `main` triggers BSR publishing — always go through a PR. Never add a `Co-Authored-By: Claude` (or any AI attribution) trailer to commit messages — standing rule across the whole workspace.

**Before starting any work:**

```bash
git checkout develop
git pull origin develop
```

**Final steps after any proto change:**

```bash
# Lint before committing
buf lint

# Stage and commit
git add wellspent/v1/...
git commit -m "feat: meaningful description of what changed"
git push origin develop

# Create PR from develop → main and immediately enable auto-merge
gh pr create --base main --head develop --title "Short title" --body "Description"
gh pr merge develop --auto --merge
```

- Always pull `develop` before starting — never work from a stale base
- Commit directly to `develop`; never commit directly to `main`
- `gh pr merge --auto` enables auto-merge — the PR lands and BSR publishing triggers once CI passes
- Never push directly to `main` — breaking change detection runs in CI on PRs to `main`

## Breaking changes

CI uses `buf breaking` with `FILE` rules. Renaming fields, changing field numbers, or removing RPCs will fail the check. To intentionally make a breaking change, update the proto version (`v2/`) rather than modifying `v1/`.

## go_package

All proto files use:
```protobuf
option go_package = "github.com/BeWellSpent/wellspent-backend/gen/wellspent/v1;wellspentv1";
```

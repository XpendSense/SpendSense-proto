# OpenAPI contracts

`.proto` is still the contract for almost the whole API. This directory holds a
**second, parallel contract** covering the handful of endpoints that are better
served as plain cacheable HTTP.

## What belongs here

An endpoint qualifies only if it is **both**:

1. **Global** — the identical response for every caller, with no auth-scoped
   filtering, and
2. **Rarely-changing** — measured in days or weeks, not seconds.

Everything else stays on ConnectRPC. Personalized reads gain nothing from HTTP
caching (every response is unique anyway) and lose the shared typed schema.
Every mutation stays on Connect, without exception.

Today that is exactly three endpoints, plus a probe:

| Endpoint | Auth | Caching |
|---|---|---|
| `GET /rest/v1/ping` | none | none — infrastructure probe |
| `GET /rest/v1/countries` | none | `public, max-age=86400, stale-while-revalidate=604800` + ETag |
| `GET /rest/v1/status/banner` | none | `public, max-age=30, stale-while-revalidate=60` + ETag |
| `GET /rest/v1/changelog` | bearer | `private, max-age=3600` + ETag |

`/changelog` is authenticated, so it is cached **privately** only. A shared
cache would need `Vary: Authorization`, which fragments the cache per token and
defeats the point.

## Rejected candidates

Recorded so the boundary does not get re-litigated from scratch:

- **`BudgetService.ListCategories`** — global *only* when no `budget_profile_id`
  filter is passed, personalized with one. Splitting a single call from a single
  screen across two transports for one conditional branch is not worth it.
- **`InviteService.GetBudgetInvite`** — public, but token-keyed, so every URL is
  unique and a shared cache never gets a second hit. It is also step one of a
  flow that continues straight into a mutation.
- **Marking these `idempotency_level = NO_SIDE_EFFECTS` instead** — Connect can
  serve such methods over cacheable GET without leaving protobuf. Rejected
  because both clients would still need protobuf codegen for these types, and
  part of the point is having a path that does not.

## Spec-first, by hand

This YAML is hand-authored and reviewed in PRs, exactly like the `.proto` files
beside it. It is **not** generated from Go handler annotations — the contract
leads and the implementations follow, which is the only way three independently
generated clients stay honest.

`redocly.yaml` at the repo root configures the linter. Run `make lint` (which
runs `buf lint`, `buf format --diff --exit-code`, and the OpenAPI lint) before
every push. CI runs the same thing.

### OpenAPI 3.0.3, deliberately

Not 3.1. `oapi-codegen` (backend) is built on kin-openapi, whose 3.1 support is
incomplete, while `openapi-typescript` (web) and `swift-openapi-generator` (iOS)
handle both. 3.0.3 is the only version all three generators agree on. The
practical consequence is `nullable: true` instead of `type: [x, "null"]`.

## How consumers get it

Unlike `.proto`, this file does **not** go through the Buf Schema Registry —
there is no equivalent channel for OpenAPI. `BeWellSpent/WellSpent-proto` is a
public repository, so each consumer fetches the raw file over HTTPS at codegen
time, with no authentication:

```
https://raw.githubusercontent.com/BeWellSpent/WellSpent-proto/main/openapi/v1/wellspent.yaml
```

| Repo | Generator | Wired into |
|---|---|---|
| `WellSpent-backend` | `oapi-codegen` (`std-http-server`) | `make generate` → `gen/rest/` |
| `WellSpent-web` | `openapi-typescript` + `openapi-fetch` | `npm run generate` → `src/gen/rest/` |
| `WellSpent-iOS` | `swift-openapi-generator` (SPM build plugin) | resolved at build; `ci_scripts/ci_post_clone.sh` fetches the YAML first |

Generated output is gitignored in all three, matching the existing policy for
protobuf-generated code.

## JSON naming

`camelCase`, matching what protobuf-es and connect-swift already produce, so
migrating a call site is close to a rename rather than a reshape.

Enums are lowercase strings (`info`, `warning`, `critical`) rather than the
proto `SCREAMING_SNAKE` form. They happen to match the values already stored in
the `severity`, `component` and `change_type` text columns, so the REST layer
needs no enum mapping at all.

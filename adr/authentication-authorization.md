# ADR: Authentication and Authorization for PlEx

- Status: Proposed
- Date: 2025-09-24
- Authors: PlEx maintainers
- Related: `adr/pl_ex.md`

## Context

Plex exposes two authentication modes in the API specification `openapi/v1/openapi-1.1.1.json`:

- JWT Authentication (recommended): device-registered Ed25519 keys, nonce, device-signed JWT exchanged for a short-lived Plex.tv JWT (~7 days) used in `X-Plex-Token` header when talking to plex.tv and for acquiring PMS-specific access tokens.
- Traditional Token Authentication (legacy): long-lived tokens used directly in `X-Plex-Token` header.

Talking to PMS (Plex Media Server) requires obtaining PMS connection info and a PMS-specific `accessToken` for the selected server via the plex.tv resources API. PMS endpoints also require a set of `X-Plex-*` headers (client id, product, version, platform, etc.). The API defaults to XML unless `Accept: application/json` is sent.

## Goals

- Provide a clear, extensible authentication abstraction that supports both JWT and legacy token flows.
- Make it easy to inject required `X-Plex-*` headers and `Accept: application/json` automatically for all requests.
- Clean separation between: (1) plex.tv authentication, (2) resource discovery, and (3) PMS requests.
- Support multiple HTTP client adapters and JSON libraries (as per `adr/pl_ex.md`).
- Facilitate secure storage and rotation of short-lived JWTs, plus migration from legacy tokens.

## Non-Goals

- Implement a UI/device activation experience (out of scope for the SDK). We will expose functions to facilitate these flows in host applications.
- Keypair generation and secure at-rest storage are caller responsibilities; we provide pluggable behaviours.

## Decisions

- Provide two pluggable behaviours:
  - `PlEx.Auth.Credentials` – responsible for obtaining and refreshing plex.tv credentials (JWT or legacy), as well as PMS `accessToken` and connection selection.
  - `PlEx.Auth.Storage` – responsible for persisting device key material and tokens (including expirations). We will ship an in-memory default and recommend user-provided secure implementations.

- Provide a first-party credentials implementation:
  - `PlEx.Auth.JWT` – Implements the device JWK registration, nonce, device-signed JWT, token exchange, rotation, and automatic refresh upon 498 Token Expired.
  - `PlEx.Auth.LegacyToken` – Wraps a static legacy token; optional validation helper against `GET https://plex.tv/api/v2/user`.

- Provide an abstraction over PMS discovery and selection:
  - `PlEx.Resources` – fetches available servers from `GET https://clients.plex.tv/api/v2/resources`, chooses the optimal connection (prefer local, then direct, then relay) and returns `{base_url, access_token}` for a selected server.

- Automatic header injection for all requests:
  - `X-Plex-Client-Identifier` (required)
  - `X-Plex-Token` (plex.tv JWT/legacy for plex.tv endpoints; PMS `accessToken` for PMS)
  - Common `X-Plex-*` metadata (product, version, platform, device, etc.)
  - `X-Plex-Pms-Api-Version` header surfaced as config (default: `1.1.1`)
  - `Accept: application/json`

- HTTP 498 Token Expired handling:
  - For plex.tv: trigger JWT refresh flow once, retry request.
  - For PMS: trigger `resources` refresh, reacquire PMS `accessToken`, retry request.

- Configuration via `use PlEx` options and/or `config :pl_ex`:
  - `auth_provider`: `PlEx.Auth.JWT` | `PlEx.Auth.LegacyToken` | custom module implementing `PlEx.Auth.Credentials`.
  - `storage`: module implementing `PlEx.Auth.Storage`.
  - `client_identifier`: required string (UUID recommended).
  - `product`, `version`, `platform`, `device`, `device_name`, `model`, etc.
  - `pms_api_version`: default "1.1.1" (header `X-Plex-Pms-Api-Version`).
  - `base_url_override`: optional PMS URL pinning for advanced scenarios.

## Architecture Overview

- `PlEx` (use macro): wires HTTP adapter, JSON library, and the `auth_provider`. Exposes high-level API modules generated from OpenAPI Spex.
- `PlEx.Auth.Credentials` behaviour:
  - `init(opts)` – initialize provider with storage and client metadata
  - `plex_token(context)` – returns `{token, exp}` for plex.tv
  - `refresh_plex_token(context)` – force refresh
  - `pms_connection(context)` – returns `{base_url, access_token, server}`
  - `invalidate(reason, context)` – drop cached tokens/connection selectively

- `PlEx.Auth.Storage` behaviour:
  - `get/put/delete` primitives for keys: `:device_keypair`, `:plex_token`, `:plex_token_exp`, `:pms_access_token`, `:pms_cached_resources`, etc.

- `PlEx.Transport` (middleware around chosen HTTP adapter):
  - Resolves target (plex.tv vs PMS) from request
  - Injects headers and tokens accordingly
  - Handles 401/422/429/498 error mappings and retry policy

## Flows

### JWT Flow (plex.tv)

1. Device registers JWK:
   - `POST https://clients.plex.tv/api/v2/auth/jwk` with `X-Plex-Client-Identifier` and existing token (on first migration) or during first-time setup if available.
   - Store public JWK thumbprint and device keypair via `Storage`.
2. Refresh cycle (every ~7 days or upon 498):
   - `GET /api/v2/auth/nonce` → returns nonce valid 5 minutes
   - Build device JWT payload `{nonce, scope, aud: "plex.tv", iss: client_identifier, iat, exp}` and sign with Ed25519 private key
   - `POST /api/v2/auth/token` with `{jwt}` → returns `auth_token` (plex.tv JWT)
   - Persist token and `exp` in `Storage`

### Legacy Token Flow (plex.tv)

- Accept a configured token; optional validation against `GET https://plex.tv/api/v2/user` on startup.

### PMS Discovery and Token

- With a valid plex.tv token, call `GET https://clients.plex.tv/api/v2/resources?includeHttps=1&includeRelay=1&includeIPv6=1` to enumerate servers.
- Choose connection URL by policy: `local > direct > relay` with HTTPS preferred when available.
- Use returned `accessToken` for PMS requests in `X-Plex-Token` header.
- Cache connections per `machineIdentifier`; invalidate on network errors or 401/498 from PMS.

## Error Handling and Retries

- Map notable responses per spec:
  - 498 (Token Expired): refresh and retry once.
  - 422 (Signature Verification Failed / Thumbprint Taken): surface clear errors.
  - 429 (Too Many Requests): exponential backoff with jitter; surface error after max attempts.
  - 401 (Unauthorized): attempt reconciling PMS access token by re-running resources discovery.

## Security Considerations

- Device private keys must never leave the host application; signing happens in-process via pluggable storage/crypto.
- Encourage OS keyring/HSM-backed storage in documentation; ship only an in-memory example.
- Do not log tokens or secrets; redact `X-Plex-Token` and JWTs in logs.

## Configuration Examples

```elixir
# config/runtime.exs
import Config

config :pl_ex,
  client_identifier: System.get_env("PLEX_CLIENT_ID"),
  product: "My Elixir App",
  version: "0.1.0",
  platform: :linux,
  device: "server",
  device_name: "pl_ex dev",
  model: "generic",
  pms_api_version: "1.1.1",
  auth_provider: PlEx.Auth.JWT,
  storage: MyApp.PlExStorage

# Or legacy token
config :pl_ex,
  auth_provider: {PlEx.Auth.LegacyToken, token: System.get_env("PLEX_TOKEN")}
```

## Testing Strategy

- Provide test helpers and an in-memory `Storage`.
- HTTP adapter stubs for plex.tv and PMS endpoints.
- Golden responses and error simulations for 498/422/429/401.
- Property tests for connection selection policy and header injection.

## Migration

- Allow applications to start with legacy tokens and migrate to JWT:
  - Register device JWK while continuing to use legacy token.
  - Switch `auth_provider` to `PlEx.Auth.JWT` once verified.

## Open Questions

- Should we expose a higher-level device-activation helper (PIN-based flow) as convenience? (out of scope here, but we could provide optional module)
  - A: let's keep this for a second moment, as long as the authentication flow works
- Policy for simultaneous multiple PMS instances: default single-preferred, with API to select by `machineIdentifier`
  - Single for now
- Backoff and retry configuration surface area (global vs per-request overrides)
  - make common options to mark single requests overrides, keeping a sensible global default (3 sync retries with exponential backoff) that we can override via macro usage

## Consequences

- Clear separation enables multiple host application needs and testing.
- Slight implementation complexity in transport middleware and cache invalidation, offset by long-term maintainability.

## Next Steps

- Implement behaviours `PlEx.Auth.Credentials` and `PlEx.Auth.Storage`.
- Implement `PlEx.Auth.JWT` and `PlEx.Auth.LegacyToken`.
- Implement `PlEx.Resources` for PMS discovery/selection.
- Add `PlEx.Transport` middleware for header injection and retry handling.
- Add documentation and examples.

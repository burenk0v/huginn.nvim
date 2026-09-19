# Changelog

All notable changes to Huginn.nvim are documented here.

## [0.1.0] - 2026-09-19

### Added

- Opinionated Neovim environment for SDETs with YAML-first project configuration.
- Project and user-local configuration with validation and JSON Schema support.
- Configurable Python tooling for Poetry, uv, pipenv, or direct execution.
- Extensible test framework adapter boundary with a built-in pytest adapter.
- Neotest and debugging integration owned by framework adapters.
- CodeCompanion integration with OpenAI-compatible providers.
- Browser-based OIDC Authorization Code + PKCE authentication for custom AI providers.
- Local AI usage tracking with optional session budget and cost estimation.
- Smoke coverage for configuration, plugin initialization, authentication, and external integration boundaries.

### Hardened

- Configuration layers are rejected as a whole when validation fails.
- Framework adapter command contracts are validated before execution.
- Plugin and command setup is retry-safe and idempotent.
- Credential storage uses restrictive permissions and atomic replacement.
- Credential records and OIDC responses are validated before use or storage.
- OIDC callback lifecycle handles invalid state, launch failures, unexpected exits, and retries safely.
- AI usage callbacks tolerate malformed external events and unavailable chat state.
- CI runs on pull requests to avoid duplicate post-merge builds.

### Notes

- Huginn requires Neovim 0.11+.
- Custom AI providers currently use OIDC authentication.
- AI credentials are stored outside project configuration.
- The v0.1.0 baseline is intentionally feature-frozen; future work should be evaluated separately from the release stabilization effort.

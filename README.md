# Huginn.nvim

**Huginn** is an opinionated Neovim environment for SDETs.

> Think. Test. Automate.

The project separates two concerns:

- **Lua** — editor, plugin and integration implementation.
- **YAML** — project-specific SDET conventions and workflows.

This keeps Huginn reusable across teams without hard-coding one company's test framework.

## Initial target stack

- Neovim 0.11+
- Python
- Poetry / uv / pipenv / direct execution
- Ruff
- ty
- pytest
- neotest
- debugpy / nvim-dap
- OpenAI-compatible AI tooling
- project-level `.sdet.yaml`

## Configuration

Huginn uses three layers, applied in this order:

1. built-in defaults;
2. project `.sdet.yaml`;
3. optional user-local `huginn.local.yaml` in Neovim's config directory.

Project configuration is for team conventions. User-local configuration is for machine- or developer-specific settings and should not be committed.

Example:

```yaml
python:
  package_manager: poetry
  formatter: ruff
  linter: ruff
  type_checker: ty

testing:
  runner: pytest
  profiles:
    default:
      - tests
    unit:
      - tests/unit
    integration:
      - tests/integration

ai:
  enabled: true
  provider: corporate
  model: company-model
  instructions: []
  providers:
    corporate:
      type: openai_compatible
      endpoint: https://ai.example.test/v1
      model: company-model
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
```

The schema is available at `config/schema.json` and is associated with `.sdet.yaml` through yaml-language-server.

Configuration files are validated before they are merged. Unknown keys and invalid value types are rejected with an error notification; the invalid layer is ignored rather than partially applied.

## Testing

Pytest execution is configurable and is built from two independent pieces:

- `python.package_manager` controls the environment prefix;
- `testing.runner` and `testing.profiles` control the test command.

Supported package-manager shortcuts are `poetry`, `uv`, `pipenv`, and `none`. Any other non-empty value is treated as an executable prefix.

Keymaps:

- `<leader>tt` — run the default profile
- `<leader>tf` — run the current file
- `<leader>tp` — choose a configured profile
- `<leader>ta` — run tests with arbitrary arguments
- `<leader>tr` — run the nearest test through neotest
- `<leader>td` — debug the nearest test

The command-generation layer is isolated in `lua/huginn/testing.lua`, so command construction can be tested without opening a terminal.

## AI

AI integration is provider-oriented. Huginn can connect to OpenAI-compatible endpoints and can authenticate desktop users through standard OIDC Authorization Code + PKCE.

Example provider configuration:

```yaml
ai:
  enabled: true
  provider: corporate
  providers:
    corporate:
      type: openai_compatible
      endpoint: https://ai.example.test/v1
      model: company-model
      auth:
        type: oidc
        issuer: https://login.example.test
        client_id: huginn
```

Run `:HuginnAIAuth` to open the corporate login page. Huginn starts a temporary localhost callback, receives the authorization code, exchanges it for tokens, and stores the credential outside the repository.

Authentication commands:

- `:HuginnAIAuth` — authenticate the configured provider in a browser
- `:HuginnAIStatus` — show authentication status
- `:HuginnAILogout` — remove the locally stored credential

The credential is stored under Neovim's data directory with restrictive file permissions. Access and refresh tokens are never stored in `.sdet.yaml`.

The OIDC client must be registered as a public desktop client and allow a localhost redirect URI. Huginn uses PKCE with the S256 challenge method.

Huginn does not require a corporate CLI for this flow.

## Design principles

- No legacy compatibility layer.
- No company-specific assumptions in the core.
- YAML describes **how the team works**; Lua describes **how Huginn works**.
- pytest remains extensible instead of being wrapped into a proprietary runner.
- AI is an assistant, not a hidden part of the test execution path.
- Security-sensitive values stay outside repository configuration.

## Repository layout

```text
lua/huginn/
├── config.lua     # configuration loading and validation
├── ai/            # AI provider authentication and integration
├── testing.lua    # test command generation
├── keymaps.lua    # editor actions
├── lazy.lua       # plugin declarations and integration setup
└── init.lua       # entry point
```

## Roadmap

1. Stabilize Python tooling and test execution.
2. Verify and complete the current AI integration against the CodeCompanion API.
3. Add framework adapters driven by project configuration.
4. Add richer SDET workflows once the configuration and integration boundaries are stable.

## License

Apache-2.0.

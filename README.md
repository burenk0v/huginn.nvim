# Huginn.nvim

**Huginn** is an opinionated Neovim environment for SDETs.

> Think. Test. Automate.

The project separates two concerns:

- **Lua** — editor, plugin and integration implementation.
- **YAML** — project-specific SDET conventions and workflows.

This makes the environment reusable across teams without hard-coding one company's test framework.

## Initial target stack

- Neovim 0.11+
- Python
- Poetry
- Ruff
- ty
- pytest
- neotest
- debugpy / nvim-dap
- OpenAI-compatible AI tooling
- project-level `.sdet.yaml`

## Configuration model

A project can contain:

```text
.sdet.yaml
```

The repository provides a starting template in `config/default.yaml` and examples in `examples/`.

The intended configuration hierarchy is:

1. Huginn defaults
2. project `.sdet.yaml`
3. optional user-local overrides

The YAML schema lives in `config/schema.json`.

## Testing

Huginn deliberately keeps pytest invocation flexible. Teams can define profiles and pass arbitrary pytest arguments rather than being forced into one framework layout.

Examples:

```text
<leader>tt    run tests
<leader>tf    run current file
<leader>ta    enter arbitrary pytest arguments
<leader>tr    run nearest test
<leader>td    debug nearest test
```

The initial implementation uses `poetry run pytest`. The command layer will become configurable through `.sdet.yaml`.

## AI

AI integration is intentionally provider-oriented. The first target is an OpenAI-compatible provider, while project instructions remain part of project configuration rather than being embedded in Lua.

Secrets must come from the environment or an external secret manager. They must never be stored in `.sdet.yaml`.

## Design principles

- No legacy compatibility layer.
- No company-specific assumptions in the core.
- YAML describes **how the team works**; Lua describes **how Huginn works**.
- pytest remains extensible instead of being wrapped into a proprietary runner.
- AI is an assistant, not a hidden part of the test execution path.
- Security-sensitive values stay outside repository configuration.

## Roadmap

1. Make YAML configuration actually drive all integrations.
2. Add Poetry-aware Python tooling and project detection.
3. Add configurable pytest profiles and arbitrary arguments.
4. Add schema-aware YAML editing.
5. Add OpenAI/compatible AI configuration.
6. Add framework adapters without coupling Huginn to a single SDET framework.

## License

Apache-2.0.

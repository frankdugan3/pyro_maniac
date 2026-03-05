# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What is PyroManiac

Extensible, declarative UI framework for Ash Framework resources. Uses Spark DSL for compile-time configuration and validation. Framework-agnostic rendering.

## Common Commands

```bash
# Setup
mix setup              # deps.get, compile, docs
mix dev.setup          # full dev setup (deps, DB, migrations, seeds, assets)
mix dev.reset          # drop DB and re-run dev.setup
mix test.setup         # create DB, generate migrations, migrate (run in test env: MIX_ENV=test mix test.setup)

# Testing
mix test               # run all tests
mix test test/path_test.exs           # single file
mix test test/path_test.exs:42        # single test by line

# Assets (dev only)
mix assets.setup       # install esbuild/tailwind
mix assets.build       # bundle JS/CSS
```

Formatting and linting is automatically handled by hooks.

## Architecture

### Spark DSL Pipeline

All UI config flows through Spark's compile-time pipeline:

1. **DSL Sections** defined in `PyroManiac.Dsl`: `views`, `forms`, `searches`, `page`
2. **Transformers** (compile-time validation/mutation): `ResolveViewResources` → `ValidateViews` → `ExpandFormActions` → `ValidatePage`
3. **Verifiers** (deferred checks): `ResourceHasExtension`
4. **Persisters** (indexing): `Views` indexes by `{action_name, type}` tuple
5. **Info API** (`PyroManiac.Info`): runtime introspection of compiled DSL data

### Other Extensions

- **Navigation** (`lib/pyro_maniac/navigation/`): DSL-based nav tree with authorization checks
- **Resource** (`lib/pyro_maniac/resource/`): `PyroManiac.Resource` extension on Ash resources, requires `default_label`
- **KanBan** (`lib/pyro_maniac/kan_ban/`): `PyroManiac.KanBan` extension on Ash resources

## Key Conventions

- Spark DSL entity keyword options CANNOT be passed inline when a `do` block is present. Use `type` inside the block: `view :read do\n  type :data_table\nend`
- DSL validation tests use `assert_raise` + inline `defmodule` — validation must happen in **transformers** (not verifiers) to be caught this way
- Test domain is a Craft Brewery (`test/support/fixtures/brewery/`): Staff, Supplier, Ingredient, Recipe, RecipeIngredient, Batch, QualityTest

## Style Guide

### Documentation

- Terse, professional, complete. No filler.
- Document modules and public functions with `@moduledoc` and `@doc`.
- All example code in docs **must** be doctests to prevent drift.
- Macros require `@doc type: :macro` annotations.
- Ash resources: put `description`, `short_name`, `plural_name` in the `resource` block. Don't duplicate description content in `@moduledoc` — Ash appends it automatically.
- Ash domains: put `description` in the `domain` block. Same deduplication rule.

### Code Comments

Use sparingly. Acceptable: surprising/unclear behavior, `TODO:`, `HACK:`. Unacceptable: narrating what code does, commented-out code, attribution.

<!-- usage-rules-start -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

[ash usage rules](deps/ash/usage-rules.md)
<!-- ash-end -->
<!-- ash:actions-start -->
## ash:actions usage
[ash:actions usage rules](deps/ash/usage-rules/actions.md)
<!-- ash:actions-end -->
<!-- ash:aggregates-start -->
## ash:aggregates usage
[ash:aggregates usage rules](deps/ash/usage-rules/aggregates.md)
<!-- ash:aggregates-end -->
<!-- ash:authorization-start -->
## ash:authorization usage
[ash:authorization usage rules](deps/ash/usage-rules/authorization.md)
<!-- ash:authorization-end -->
<!-- ash:calculations-start -->
## ash:calculations usage
[ash:calculations usage rules](deps/ash/usage-rules/calculations.md)
<!-- ash:calculations-end -->
<!-- ash:code_interfaces-start -->
## ash:code_interfaces usage
[ash:code_interfaces usage rules](deps/ash/usage-rules/code_interfaces.md)
<!-- ash:code_interfaces-end -->
<!-- ash:code_structure-start -->
## ash:code_structure usage
[ash:code_structure usage rules](deps/ash/usage-rules/code_structure.md)
<!-- ash:code_structure-end -->
<!-- ash:data_layers-start -->
## ash:data_layers usage
[ash:data_layers usage rules](deps/ash/usage-rules/data_layers.md)
<!-- ash:data_layers-end -->
<!-- ash:exist_expressions-start -->
## ash:exist_expressions usage
[ash:exist_expressions usage rules](deps/ash/usage-rules/exist_expressions.md)
<!-- ash:exist_expressions-end -->
<!-- ash:generating_code-start -->
## ash:generating_code usage
[ash:generating_code usage rules](deps/ash/usage-rules/generating_code.md)
<!-- ash:generating_code-end -->
<!-- ash:migrations-start -->
## ash:migrations usage
[ash:migrations usage rules](deps/ash/usage-rules/migrations.md)
<!-- ash:migrations-end -->
<!-- ash:query_filter-start -->
## ash:query_filter usage
[ash:query_filter usage rules](deps/ash/usage-rules/query_filter.md)
<!-- ash:query_filter-end -->
<!-- ash:querying_data-start -->
## ash:querying_data usage
[ash:querying_data usage rules](deps/ash/usage-rules/querying_data.md)
<!-- ash:querying_data-end -->
<!-- ash:relationships-start -->
## ash:relationships usage
[ash:relationships usage rules](deps/ash/usage-rules/relationships.md)
<!-- ash:relationships-end -->
<!-- ash:testing-start -->
## ash:testing usage
[ash:testing usage rules](deps/ash/usage-rules/testing.md)
<!-- ash:testing-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework_

[ash_postgres usage rules](deps/ash_postgres/usage-rules.md)
<!-- ash_postgres-end -->
<!-- ash_postgres:advanced_features-start -->
## ash_postgres:advanced_features usage
[ash_postgres:advanced_features usage rules](deps/ash_postgres/usage-rules/advanced_features.md)
<!-- ash_postgres:advanced_features-end -->
<!-- ash_postgres:best_practices-start -->
## ash_postgres:best_practices usage
[ash_postgres:best_practices usage rules](deps/ash_postgres/usage-rules/best_practices.md)
<!-- ash_postgres:best_practices-end -->
<!-- ash_postgres:check_constraints-start -->
## ash_postgres:check_constraints usage
[ash_postgres:check_constraints usage rules](deps/ash_postgres/usage-rules/check_constraints.md)
<!-- ash_postgres:check_constraints-end -->
<!-- ash_postgres:configuration-start -->
## ash_postgres:configuration usage
[ash_postgres:configuration usage rules](deps/ash_postgres/usage-rules/configuration.md)
<!-- ash_postgres:configuration-end -->
<!-- ash_postgres:custom_indexes-start -->
## ash_postgres:custom_indexes usage
[ash_postgres:custom_indexes usage rules](deps/ash_postgres/usage-rules/custom_indexes.md)
<!-- ash_postgres:custom_indexes-end -->
<!-- ash_postgres:custom_sql_statements-start -->
## ash_postgres:custom_sql_statements usage
[ash_postgres:custom_sql_statements usage rules](deps/ash_postgres/usage-rules/custom_sql_statements.md)
<!-- ash_postgres:custom_sql_statements-end -->
<!-- ash_postgres:foreign_keys-start -->
## ash_postgres:foreign_keys usage
[ash_postgres:foreign_keys usage rules](deps/ash_postgres/usage-rules/foreign_keys.md)
<!-- ash_postgres:foreign_keys-end -->
<!-- ash_postgres:migrations-start -->
## ash_postgres:migrations usage
[ash_postgres:migrations usage rules](deps/ash_postgres/usage-rules/migrations.md)
<!-- ash_postgres:migrations-end -->
<!-- ash_postgres:multitenancy-start -->
## ash_postgres:multitenancy usage
[ash_postgres:multitenancy usage rules](deps/ash_postgres/usage-rules/multitenancy.md)
<!-- ash_postgres:multitenancy-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- spark-start -->
## spark usage
_Generic tooling for building DSLs_

[spark usage rules](deps/spark/usage-rules.md)
<!-- spark-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A config-driven dev tool for Elixir projects to manage AGENTS.md files and agent skills from dependencies_

[usage_rules usage rules](deps/usage_rules/usage-rules.md)
<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
[usage_rules:elixir usage rules](deps/usage_rules/usage-rules/elixir.md)
<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
[usage_rules:otp usage rules](deps/usage_rules/usage-rules/otp.md)
<!-- usage_rules:otp-end -->
<!-- usage-rules-end -->

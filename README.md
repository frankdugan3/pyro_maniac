[![hex.pm](https://img.shields.io/hexpm/l/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![hex.pm](https://img.shields.io/hexpm/v/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/pyro_maniac)
[![hex.pm](https://img.shields.io/hexpm/dt/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![github.com](https://img.shields.io/github/last-commit/frankdugan3/pyro_maniac.svg)](https://github.com/frankdugan3/pyro_maniac)

# PyroManiac

Extensible, declarative, framework-agnostic UI DSL for Ash Framework resources.

PyroManiac is the DSL layer only — it compiles your UI configuration and
exposes it via `PyroManiac.Info`. Rendering is provided by a separate
renderer library such as
[`pyro_maniac_live_view`](https://github.com/frankdugan3/pyro_maniac_live_view).

- Compile-time validation of UI configuration (Spark transformers and verifiers)
- DSL sections: `page`, `views`, `forms`, `searches`
- View types: `data_table`, `grid`, `calendar`, `gantt`, `kanban`, `list`, `render`, `delegated`
- Forms with field groups, wizard steps, conditional visibility, and bulk actions
- Declarative navigation (`PyroManiac.Navigation`) with a precomputed route manifest
- Kanban support (`PyroManiac.KanBan` extension on resources)
- Renderer-agnostic — pair with the renderer for your stack

## About

For more details on PyroManiac, check out the [About](https://hexdocs.pm/pyro_maniac/about.html) page.

## Installation

Follow the [Get Started](https://hexdocs.pm/pyro_maniac/get-started.html) guide
to add the DSL to your Ash project, then install the renderer library for your
chosen stack.

## Development

As long as Elixir is already installed:

```sh
git clone git@github.com:frankdugan3/pyro_maniac.git
cd pyro_maniac
mix setup
```

For writing docs, there is a handy watcher script that automatically rebuilds/reloads the docs locally: `./watch_docs.sh`

## Prior Art

- [AshAdmin](https://github.com/ash-project/ash_admin): An admin ui for Ash Resources.

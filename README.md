[![hex.pm](https://img.shields.io/hexpm/l/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![hex.pm](https://img.shields.io/hexpm/v/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![Documentation](https://img.shields.io/badge/documentation-gray)](https://hexdocs.pm/pyro_maniac)
[![hex.pm](https://img.shields.io/hexpm/dt/pyro_maniac.svg)](https://hex.pm/packages/pyro_maniac)
[![github.com](https://img.shields.io/github/last-commit/frankdugan3/pyro_maniac.svg)](https://github.com/frankdugan3/pyro_maniac)

# PyroManiac

Extensible, declarative, framework-agnostic UI DSL for Ash Framework resources.

PyroManiac is the DSL layer only — it compiles your UI configuration and
exposes it via `PyroManiac.Info`. Rendering is provided by a separate
renderer library.

- Compile-time validation of UI configuration (Spark transformers and verifiers)
- A page module: the `page` section (with its `route`), and the top-level `view` and `search` entities; a module without the `page` section declares views and searches that the pages reuse
- View types: `data_table`, `grid`, `card`, `calendar`, `gantt`, `kanban`, `list`, `timeline`, `render`
- Views that run their actions: forms with sections, tabs, wizard steps, and conditional visibility; a declared state of the unsaved inputs (guard, recover, or discard); confirmations, inline cell edits, inline new rows, clones, drag to reorder, and bulk actions
- The status and the transitions of a state machine or a workflow (`workflow` node)
- Filters: search presets, and filters that users build, save, and share (`PyroManiac.FilterPresets`)
- One record tree for a view and the forms of its actions (`only [names]` for the differences), with links between the cards
- Portable content: `render`, `description`, and column `label` take a text or an Ash expression for every renderer, and an implementation for one renderer
- Declarative navigation (`PyroManiac.Navigation`) with a precomputed route manifest (the routes of the pages, checked for overlap) and a command palette
- Kanban support (`PyroManiac.KanBan`) with static lanes (an enum) or dynamic lanes (a `belongs_to`; lanes that users add, rename, delete, and move, stored with `PyroManiac.KanBan.Lanes`), and user-defined order (`PyroManiac.Ordering`) extensions on resources
- Configurable decorations: the meaning of a value, mapped to styles by each renderer
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

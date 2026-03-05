# About

PyroManiac is a declarative, framework-agnostic UI DSL for Ash Framework
resources. It uses [Spark](https://hexdocs.pm/spark) to compile your UI
configuration at build time and exposes the result through
`PyroManiac.Info` for renderers to consume.

## What it is

- A Spark DSL with four sections — `page`, `views`, `forms`, `searches`
- Resource and navigation extensions — `PyroManiac.Resource`, `PyroManiac.Navigation`, `PyroManiac.KanBan`
- A runtime introspection API — `PyroManiac.Info` (and the `*.Info` modules per extension)

## What it is not

PyroManiac does not render anything by itself. Rendering, routing, and
real-time wiring are the responsibility of a separate renderer library.
Pair PyroManiac with the renderer for your stack — for example
[`pyro_maniac_live_view`](https://github.com/frankdugan3/pyro_maniac_live_view)
for Phoenix LiveView applications.

## Why

The default model in most web frameworks is to scaffold UI code, then
customize it. That trades repetition for control and ages poorly: the
copy-pasted boilerplate drifts from any upstream improvement, and small
schema changes ripple through every page.

PyroManiac inverts that: declare the UI as data on the resource, validate
it at compile time, and let the renderer turn it into pixels. Resource
changes and DSL changes both surface as compile errors instead of subtle
runtime drift.

## Getting started

Follow the [Get Started](get-started.html) guide.

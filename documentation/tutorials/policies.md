# Policies

A renderer authorizes every read and action with the scope of the user, and
Ash refuses what the policies forbid. To decide what it shows (an action
button, a link, a navigation item), a server renderer calls:

```elixir
Ash.can?({record_or_resource, action}, scope, maybe_is: true, run_queries?: false)
```

This call does not query the database. Only the strict check of the
policies runs, and an answer that it cannot give is `true`
([Authorization](../renderers/renderer-overview.md#authorization)). So the
policies decide how exact the UI is. A policy that the strict check
decides gives an exact answer: the user sees only what they can do. A
policy that needs data gives `true`: the user sees the control, and the
action fails when it runs.

Write the policies so that the strict check decides them where it can.

## What the strict check decides

`Ash.can?` with `maybe_is: true, run_queries?: false`:

| The policy | The answer |
|---|---|
| Simple checks of the actor (`Ash.Policy.SimpleCheck`: a role, an active account) | Exact |
| An expression check, with the record (`{record, :update}`) | Exact, from the loaded fields of the record |
| An expression check on a read, or with no record | `true` for each actor |
| An expression check that refers to the actor (`^actor(:id)`), with no actor | `false` |
| An expression check that does not refer to the actor, with no actor | `true` |
| A runtime check (`type: :manual`, or a check that needs the data) | `true`, also with no actor |

## Simple checks of the actor

A simple check decides from the actor alone. Load what it needs on the
actor of the scope (the roles, the employee), so that it never queries.

```elixir
defmodule MyApp.Checks.ActorHasRole do
  use Ash.Policy.SimpleCheck

  @impl true
  def describe(opts), do: "actor has a role of #{inspect(opts[:roles])}"

  @impl true
  def requires_original_data?(_actor, _opts), do: false

  @impl true
  def match?(nil, _context, _opts), do: false
  def match?(actor, _context, opts), do: Enum.any?(actor.roles, &(&1 in opts[:roles]))
end
```

`requires_original_data?/2` gives `false`: the check does not need the
record, so it decides before Ash reads anything.

## The simple checks first

The checks of a policy run in order, and the first check that decides
gives the result. Put the simple checks before the expression checks:

```elixir
policy action(:update) do
  forbid_unless actor_is_active()
  authorize_if expr(owner_id == ^actor(:id))
end
```

For an inactive actor, `forbid_unless actor_is_active()` decides at once:
`false`. With the expression first, the strict check cannot decide, and an
inactive actor sees the button (`true`).

## A strict read policy

When the checks of a read policy are all simple checks, set
`access_type :strict`. A read without access then fails at once, and does
not give an empty list.

```elixir
policy action_type(:read) do
  access_type :strict
  forbid_unless actor_is_active()
  authorize_if actor_has_role(roles: [:planner, :admin])
end
```

## An absent actor

An expression check that does not refer to the actor gives `true` with no
actor, so the navigation shows the page to a user who is not signed in.
Forbid an absent actor first, in a strict policy:

```elixir
policies do
  policy actor_absent() do
    access_type :strict
    forbid_if always()
  end

  policy action_type(:read) do
    authorize_if expr(public? == true)
  end
end
```

## A strict check next to a filter check

A read of many records needs a filter check: the filter gives the records
that the user can read. The filter cannot answer "can the user read any?"
without a query. Add a simple check that gives that answer from the actor,
from the same source of truth (for example the same list of roles), and do
not keep a second copy of the rule:

```elixir
policy action_type(:read) do
  forbid_unless actor_can_read_some_kind()
  authorize_if filter_by_permitted_kinds()
end
```

## IDs, not relationships

`relates_to_actor_via/1` is a filter: with a record, it needs a query. When
the record has the foreign key, compare the IDs in a simple check, or in an
expression on the attribute (`expr(owner_id == ^actor(:id))`). The strict
check decides both from the loaded record.

## Pass the record

`Ash.can?({resource, action}, ...)` has no record, so each expression check
gives `true`. When the renderer has the record (a row, a card), it passes
it: `Ash.can?({record, action}, ...)`. The expression checks then run on the
fields of the record, with no query. Load the fields that the checks refer
to with the record (the loads of the view).

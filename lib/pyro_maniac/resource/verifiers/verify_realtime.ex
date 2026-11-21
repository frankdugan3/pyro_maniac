defmodule PyroManiac.Resource.Verifiers.VerifyRealtime do
  @moduledoc false
  use Spark.Dsl.Verifier

  alias PyroManiac.Dsl.Error

  @section [:pyro_maniac, :realtime]

  @impl true
  def verify(dsl) do
    if Spark.Dsl.Verifier.get_persisted(dsl, :pyro_maniac_realtime?, false) do
      module = Spark.Dsl.Verifier.get_persisted(dsl, :module)

      with :ok <- verify_except(dsl, module),
           :ok <- verify_bulk(dsl, module),
           :ok <- verify_setup(dsl, module),
           :ok <- verify_bulk_setup(dsl, module) do
        verify_coverage(dsl, module)
      end
    else
      :ok
    end
  end

  defp verify_except(dsl, module) do
    except = Spark.Dsl.Extension.get_opt(dsl, @section, :except, [])

    case Enum.find(except, &(not notifying_action?(dsl, &1))) do
      nil ->
        :ok

      name ->
        error(dsl, module, :except,
          why: "`except` has #{inspect(name)}, which is not a create, update, or destroy action",
          fix: "remove #{inspect(name)} from `except`"
        )
    end
  end

  defp notifying_action?(dsl, name) do
    match?(
      %{type: type} when type in [:create, :update, :destroy],
      Ash.Resource.Info.action(dsl, name)
    )
  end

  # An atom of `bulk` that is not an action is an event of
  # `PyroManiac.Realtime.broadcast_bulk/3`.
  defp verify_bulk(dsl, module) do
    except = Spark.Dsl.Extension.get_opt(dsl, @section, :except, [])

    bulk_actions(dsl)
    |> Enum.find_value(:ok, fn action ->
      cond do
        action.type not in [:create, :update, :destroy] ->
          error(dsl, module, :bulk,
            why:
              "`bulk` has #{inspect(action.name)}, which is a #{action.type} action, not a create, update, or destroy action",
            fix: "remove #{inspect(action.name)} from `bulk`"
          )

        action.name in except ->
          error(dsl, module, :bulk,
            why:
              "#{inspect(action.name)} is in `bulk` and in `except`: an action in `except` sends no notification",
            fix: "remove #{inspect(action.name)} from `bulk` or from `except`"
          )

        true ->
          nil
      end
    end)
  end

  defp bulk_actions(dsl) do
    dsl
    |> Spark.Dsl.Extension.get_opt(@section, :bulk, [])
    |> Enum.map(&Ash.Resource.Info.action(dsl, &1))
    |> Enum.reject(&is_nil/1)
  end

  @record_filter &PyroManiac.Realtime.record_notification?/1

  defp verify_bulk_setup(dsl, module) do
    actions = bulk_actions(dsl)
    notifiers = Spark.Dsl.Verifier.get_persisted(dsl, :notifiers, [])

    unfiltered =
      for action <- actions,
          pub <- Spark.Dsl.Extension.get_entities(dsl, [:pub_sub]),
          covers?(pub, action),
          pub.filter != @record_filter,
          do: action.name

    cond do
      actions == [] ->
        :ok

      PyroManiac.Realtime.BulkNotifier not in notifiers ->
        error(dsl, module, :bulk,
          why:
            "`bulk` has actions, but the resource does not use `PyroManiac.Realtime.BulkNotifier`",
          fix: "add `PyroManiac.Realtime.BulkNotifier` to `notifiers:`, or use `mode :auto`"
        )

      unfiltered != [] ->
        error(dsl, module, :bulk,
          why:
            "a publication of #{inspect(hd(unfiltered))} (in `bulk`) has no filter " <>
              "`&PyroManiac.Realtime.record_notification?/1`, so its bulk operations " <>
              "also send one notification for each record",
          fix:
            "add `filter: &PyroManiac.Realtime.record_notification?/1` to the publication, or use `mode :auto`"
        )

      true ->
        :ok
    end
  end

  defp verify_setup(dsl, module) do
    cond do
      Ash.Notifier.PubSub not in Spark.Dsl.Verifier.get_persisted(dsl, :notifiers, []) ->
        error(dsl, module, :mode,
          why: "the resource has a `realtime` section, but it does not use `Ash.Notifier.PubSub`",
          fix:
            "add `notifiers: [Ash.Notifier.PubSub]` and a `pub_sub` section, or use `mode :auto`"
        )

      is_nil(Spark.Dsl.Extension.get_opt(dsl, [:pub_sub], :module)) ->
        error(dsl, module, :mode,
          why: "the `pub_sub` section of the resource has no `module`",
          fix:
            "set `module` in `pub_sub`, or use `mode :auto` with `config :pyro_maniac, :realtime, module: ...`"
        )

      is_nil(Spark.Dsl.Extension.get_opt(dsl, [:pub_sub], :prefix)) ->
        error(dsl, module, :mode,
          why: "the `pub_sub` section of the resource has no `prefix`",
          fix: "set `prefix` in `pub_sub`, or use `mode :auto`"
        )

      true ->
        :ok
    end
  end

  defp verify_coverage(dsl, module) do
    except = Spark.Dsl.Extension.get_opt(dsl, @section, :except, [])

    dsl
    |> PyroManiac.Resource.Info.exposed()
    |> Enum.map(&Ash.Resource.Info.action(dsl, &1.name))
    |> Enum.reject(&is_nil/1)
    |> Enum.filter(&(&1.type in [:create, :update, :destroy]))
    |> Enum.reject(&(&1.name in except))
    |> Enum.find(&(not PyroManiac.Resource.Info.published?(dsl, &1)))
    |> case do
      nil ->
        :ok

      action ->
        error(dsl, module, :except,
          why:
            "action #{inspect(action.name)} is exposed, but no publication with a static " <>
              "topic sends its notification",
          fix:
            "add a publication for #{inspect(action.name)} to `pub_sub`, add " <>
              "#{inspect(action.name)} to `except` in `realtime`, or use `mode :auto`"
        )
    end
  end

  defp covers?(%Ash.Notifier.PubSub.Publication{action: name}, action) when not is_nil(name),
    do: name == action.name

  defp covers?(%Ash.Notifier.PubSub.Publication{type: type, except: except}, action),
    do: type == action.type and action.name not in List.wrap(except)

  defp covers?(_, _), do: false

  defp error(dsl, module, option, opts) do
    {:error,
     Error.build(
       [
         module: module,
         location:
           Spark.Dsl.Extension.get_opt_anno(dsl, @section, option) ||
             Spark.Dsl.Extension.get_section_anno(dsl, @section),
         path: @section ++ [option]
       ] ++ opts
     )}
  end
end

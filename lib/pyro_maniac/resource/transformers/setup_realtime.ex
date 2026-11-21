defmodule PyroManiac.Resource.Transformers.SetupRealtime do
  @moduledoc false
  use Spark.Dsl.Transformer

  alias Spark.Dsl.Transformer

  @section [:pyro_maniac, :realtime]

  # `bulk` names actions, and `defaults` makes actions.
  @impl true
  def after?(Ash.Resource.Transformers.DefaultActions), do: true
  def after?(_), do: false

  @impl true
  def transform(dsl) do
    if Map.has_key?(dsl, @section) do
      dsl = Transformer.persist(dsl, :pyro_maniac_realtime?, true)

      case Transformer.get_option(dsl, @section, :mode, :validate) do
        :auto -> {:ok, setup(dsl)}
        _ -> {:ok, dsl}
      end
    else
      {:ok, Transformer.persist(dsl, :pyro_maniac_realtime?, false)}
    end
  end

  defp setup(dsl) do
    module = Transformer.get_persisted(dsl, :module)

    dsl
    |> add_notifier()
    |> set_options(module)
    |> add_publications()
  end

  defp add_notifier(dsl) do
    notifiers = Transformer.get_persisted(dsl, :notifiers, [])

    added =
      if bulk_actions?(dsl),
        do: [Ash.Notifier.PubSub, PyroManiac.Realtime.BulkNotifier],
        else: [Ash.Notifier.PubSub]

    Transformer.persist(dsl, :notifiers, Enum.uniq(added ++ notifiers))
  end

  # The other atoms of `bulk` are events of `broadcast_bulk/3`.
  defp bulk_actions?(dsl) do
    dsl
    |> Transformer.get_option(@section, :bulk, [])
    |> Enum.any?(&Ash.Resource.Info.action(dsl, &1))
  end

  # A `pub_sub` section that is not written has no defaults (Spark applies
  # them only when the section macro runs). Validate the options against the
  # section schema to get them, then set each option that `pub_sub` does not
  # set.
  defp set_options(dsl, module) do
    wanted =
      [
        module:
          Transformer.get_option(dsl, @section, :module) ||
            PyroManiac.Realtime.default_module(),
        prefix:
          Transformer.get_option(dsl, @section, :prefix) ||
            PyroManiac.Realtime.default_prefix(module)
      ]
      |> Enum.reject(fn {_key, value} -> is_nil(value) end)

    {:ok, opts} = Spark.Options.validate(wanted, pub_sub_schema())

    Enum.reduce(opts, dsl, fn {key, value}, dsl ->
      case Transformer.get_option(dsl, [:pub_sub], key) do
        nil -> Transformer.set_option(dsl, [:pub_sub], key, value)
        _written -> dsl
      end
    end)
  end

  defp add_publications(dsl) do
    except = Transformer.get_option(dsl, @section, :except, [])
    record_topics? = Transformer.get_option(dsl, @section, :record_topics?, true)

    publications =
      [{:create, ["*"]}, {:update, ["*"]}, {:destroy, ["*"]}] ++
        if record_topics?,
          do: [{:update, ["updated", [:id, nil]]}, {:destroy, ["destroyed", [:id, nil]]}],
          else: []

    filter =
      if bulk_actions?(dsl), do: [filter: &PyroManiac.Realtime.record_notification?/1], else: []

    publications
    |> Enum.reverse()
    |> Enum.reduce(dsl, fn {type, topic}, dsl ->
      publication =
        Transformer.build_entity!(
          Ash.Notifier.PubSub,
          [:pub_sub],
          :publish_all,
          [type: type, topic: topic, except: except] ++ filter
        )

      Transformer.add_entity(dsl, [:pub_sub], publication)
    end)
  end

  defp pub_sub_schema do
    Ash.Notifier.PubSub.sections()
    |> Enum.find(&(&1.name == :pub_sub))
    |> Map.fetch!(:schema)
  end
end

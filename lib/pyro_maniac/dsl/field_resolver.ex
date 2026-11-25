defmodule PyroManiac.Dsl.FieldResolver do
  @moduledoc """
  Fills in what a form input does not say about itself, from the Ash
  resource: the input type of a `field`, whether nil is allowed, the options
  of a `select`, the search of a `combobox`, the options of an `input`, and
  the size. It also validates each input against the resource and the action.

  Shared so that an input resolves the same wherever it is declared: an
  argument of the read action of a view by the same rules as an input of
  an action of a view.

  Runs at compile time. The context has `:module` (error attribution),
  `:path_root` (`[:forms]`, the internal path of the actions, or `[:views]`,
  where the error points), and
  optionally `:level_inputs` (a map from a full path to the names of the
  inputs at that level, for `^input/1`).
  """
  @moduledoc group: "PyroManiac"

  alias PyroManiac.Dsl.Error
  alias PyroManiac.Dsl.Expression
  alias PyroManiac.Form.{Combobox, Field, Input, Select}
  alias PyroManiac.Info
  alias PyroManiac.TypeInfer
  alias Spark.Dsl.Entity
  alias Spark.Dsl.Transformer

  @built_in_field_types ~w(
    attachment boolean checkbox date datetime default email interval
    naive_datetime nested_form number password search tel text textarea time
    toggle url
  )a

  @string_types [Ash.Type.String, Ash.Type.CiString]
  @max_limit 100

  @doc "The `type` values of a `field`."
  @spec built_in_field_types() :: [atom()]
  def built_in_field_types, do: @built_in_field_types

  @doc """
  Builds an input entity the way the DSL would have. `kind` is `:field`,
  `:select`, `:combobox`, or `:input`.
  """
  @spec new_input(atom(), keyword()) :: struct()
  def new_input(kind, attrs),
    do: Transformer.build_entity!(PyroManiac.Dsl, [:views, :view], kind, attrs)

  @doc "Builds a `PyroManiac.Form.Field` the way the DSL would have."
  @spec new_field(keyword()) :: Field.t()
  def new_field(attrs), do: new_input(:field, attrs)

  @doc """
  Builds the input entity that fits an attribute or argument of `resource`:
  a `combobox` for the foreign key of a `belongs_to`, a `select` for a
  closed set of values, else a `field`. For inputs that the transformers
  make (for example the read arguments of a view), not for inputs that an
  author writes.
  """
  @spec new_input_for(Ash.Resource.t(), map(), keyword()) :: struct()
  def new_input_for(resource, attr_info, attrs) do
    cond do
      belongs_to_for(resource, attr_info.name) ->
        new_input(:combobox, attrs)

      TypeInfer.closed_values(attr_info.type, Map.get(attr_info, :constraints) || []) ->
        new_input(:select, attrs)

      true ->
        new_input(:field, attrs)
    end
  end

  @doc """
  Resolves one input against the resource and the action. The resource is
  the form resource; the input is resolved at its `__full_path__`.
  """
  @spec resolve(struct(), Ash.Resource.t(), atom(), map()) :: struct()
  def resolve(input, resource, action_name, context) do
    field_resource = Info.resource_by_path(resource, input.__full_path__ || [])
    attr_info = Info.action_field_info(field_resource, action_name, input.name)

    context = Map.put(context, :action_name, action_name)

    input
    |> do_resolve(field_resource, attr_info, context)
    |> resolve_size(field_resource, attr_info)
  end

  defp do_resolve(%Field{type: type} = field, _resource, attr_info, context)
       when type in [:attachment, :nested_form] do
    field
    |> put_allow_nil(attr_info)
    |> validate_field_type(context)
  end

  defp do_resolve(%Field{} = field, resource, attr_info, context) do
    validate_field_type(field, context)
    validate_not_belongs_to(field, resource, context)
    closed = attr_info && closed_values(attr_info)
    validate_not_closed(field, closed, context)

    if attr_info do
      type =
        if field.type == :default,
          do: TypeInfer.infer_input_type(nil, attr_info),
          else: field.type

      %{
        field
        | type: type,
          __enum_options__: closed || [],
          "__multiple?__": closed != nil and array?(attr_info)
      }
      |> put_allow_nil(attr_info)
    else
      field
    end
  end

  defp do_resolve(%Select{} = select, _resource, attr_info, context) do
    options =
      case select.options do
        [_ | _] = options -> Enum.map(options, &explicit_option/1)
        _ -> attr_info && closed_values(attr_info)
      end

    if attr_info && options in [nil, []] do
      Error.raise!(
        module: context.module,
        location: Entity.anno(select),
        path: input_path(context, select),
        why:
          "select #{inspect(select.name)} has no options: the type has no closed set of " <>
            "values (a `one_of` constraint, an `Ash.Type.Enum`, or a new type of them)",
        fix: "set `options`, or use `field #{inspect(select.name)}`"
      )
    end

    %{
      select
      | __enum_options__: options || [],
        "__multiple?__": attr_info != nil and array?(attr_info)
    }
    |> put_allow_nil(attr_info)
  end

  defp do_resolve(%Combobox{} = combobox, resource, attr_info, context) do
    belongs_to = belongs_to_for(resource, combobox.name)

    managed =
      if is_nil(belongs_to),
        do: managed_relationship(resource, context[:action_name], combobox.name)

    combobox
    |> put_allow_nil(attr_info)
    |> resolve_combobox(belongs_to || managed, resource, attr_info, context)
    |> Map.put(:"__multiple?__", match?(%{cardinality: :many}, managed))
    |> maybe_strip_id_label(belongs_to)
  end

  defp do_resolve(%Input{type: {module, opts}} = input, _resource, attr_info, context) do
    case Spark.Options.validate(opts, module.schema()) do
      {:ok, opts} ->
        %{input | __opts__: opts}
        |> put_allow_nil(attr_info)

      {:error, %Spark.Options.ValidationError{key: bad_key} = error} ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(input, :type) || Entity.anno(input),
          path: input_path(context, input),
          why:
            "the options of input #{inspect(input.name)} (#{inspect(module)}) are invalid: " <>
              Exception.message(error),
          suggestions: Error.did_you_mean(bad_key, Keyword.keys(module.schema()))
        )
    end
  end

  # A plain `field` on the foreign key of a `belongs_to` is an error: its
  # input is a combobox (no inference, form DSL plan Q12).
  defp validate_not_belongs_to(%Field{type: :default} = field, resource, context) do
    if belongs_to = belongs_to_for(resource, field.name) do
      Error.raise!(
        module: context.module,
        location: Entity.anno(field),
        path: input_path(context, field),
        why:
          "field #{inspect(field.name)} is the foreign key of the `belongs_to` " <>
            "#{inspect(belongs_to.name)}, so its input is a combobox",
        fix: "use `combobox #{inspect(field.name)}` instead of `field #{inspect(field.name)}`"
      )
    end
  end

  defp validate_not_belongs_to(_field, _resource, _context), do: :ok

  # A plain `field` on a closed set of values is an error: its input is a
  # select (Q12).
  defp validate_not_closed(%Field{type: :default} = field, closed, context)
       when closed not in [nil, false] do
    Error.raise!(
      module: context.module,
      location: Entity.anno(field),
      path: input_path(context, field),
      why: "field #{inspect(field.name)} has a closed set of values, so its input is a select",
      fix:
        "use `select #{inspect(field.name)}` instead of `field #{inspect(field.name)}`, " <>
          "or `type: :checkbox` for a checkbox group"
    )
  end

  defp validate_not_closed(_field, _closed, _context), do: :ok

  defp put_allow_nil(input, nil), do: input

  defp put_allow_nil(input, attr_info),
    do: %{input | "__allow_nil?__": Map.get(attr_info, :allow_nil?, true)}

  defp closed_values(attr_info),
    do: TypeInfer.closed_values(attr_info.type, Map.get(attr_info, :constraints) || [])

  defp array?(%{type: {:array, _}}), do: true
  defp array?(_), do: false

  defp explicit_option({label, value}),
    do: %{value: value, label: to_string(label), description: nil}

  defp explicit_option(value),
    do: %{value: value, label: TypeInfer.fallback_label(value), description: nil}

  # The relationship that the action manages with the argument `name`
  # (`change manage_relationship(:name, :relationship, ...)`).
  defp managed_relationship(_resource, nil, _name), do: nil

  defp managed_relationship(resource, action_name, name) do
    with %{changes: changes} <- Ash.Resource.Info.action(resource, action_name),
         opts when is_list(opts) <- Enum.find_value(changes, &manage_opts(&1, name)) do
      Ash.Resource.Info.relationship(resource, opts[:relationship])
    else
      _ -> nil
    end
  end

  defp manage_opts(%{change: {Ash.Resource.Change.ManageRelationship, opts}}, name),
    do: if(opts[:argument] == name, do: opts)

  defp manage_opts(_change, _name), do: nil

  defp resolve_combobox(
         combobox,
         %{destination: dest} = belongs_to,
         _resource,
         _attr_info,
         context
       ) do
    value_key = combobox.value_key || primary_key_attr(dest)

    label_key =
      combobox.label_key || PyroManiac.Resource.Info.default_label(dest) || :label

    combobox
    |> Map.merge(%{
      __mode__: :select,
      __resource__: dest,
      __relationship__: belongs_to.name,
      value_key: value_key,
      label_key: label_key
    })
    |> resolve_query(context)
  end

  defp resolve_combobox(combobox, nil, resource, attr_info, context) do
    validate_free_text_type!(combobox, attr_info, context)

    if Enum.any?(combobox.link_to || [], &(&1.page != false)) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :link_to) || Entity.anno(combobox),
        path: input_path(context, combobox, :link_to),
        why:
          "free-text combobox #{inspect(combobox.name)} has no record to link to: " <>
            "it is not the foreign key of a `belongs_to`",
        fix: "remove `link_to`"
      )
    end

    value_key = combobox.value_key || combobox.name

    if combobox.label_key && combobox.label_key != value_key do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :label_key) || Entity.anno(combobox),
        path: input_path(context, combobox, :label_key),
        why:
          "free-text combobox #{inspect(combobox.name)} shows its value as the label, but " <>
            "`label_key` is #{inspect(combobox.label_key)} and the value key is #{inspect(value_key)}",
        fix: "remove `label_key` from the combobox"
      )
    end

    combobox
    |> Map.merge(%{
      __mode__: :free_text,
      __resource__: resource,
      value_key: value_key,
      label_key: value_key
    })
    |> resolve_query(context)
  end

  defp validate_free_text_type!(_combobox, %{type: type}, _context) when type in @string_types,
    do: :ok

  defp validate_free_text_type!(_combobox, nil, _context), do: :ok

  defp validate_free_text_type!(combobox, %{type: type}, context) do
    Error.raise!(
      module: context.module,
      location: Entity.anno(combobox),
      path: input_path(context, combobox),
      why:
        "combobox #{inspect(combobox.name)} is not the foreign key of a `belongs_to`, " <>
          "so it is free text, and free text needs a `:string` or `:ci_string`. " <>
          "The type is #{inspect(type)}",
      fix: "use a `:string` or `:ci_string`, a `belongs_to` foreign key, or `field`/`select`"
    )
  end

  defp resolve_query(combobox, context) do
    resource = combobox.__resource__
    read_action = combobox.read_action || primary_read!(resource, combobox, context)
    action = validate_read_action!(resource, read_action, combobox, context)
    validate_arguments!(resource, action, combobox, context)

    search = if combobox.search == nil, do: [combobox.label_key], else: combobox.search
    validate_search!(resource, search, combobox, context)

    sort = combobox.sort || [{combobox.label_key, :asc}]
    validate_sort!(resource, sort, combobox, context)
    validate_limit!(combobox, context)
    validate_keys!(resource, combobox, context)
    validate_filter!(resource, combobox, context)

    combobox = %{combobox | read_action: read_action, search: search, sort: sort}
    validate_search_used!(combobox, context)

    inputs =
      Enum.uniq(
        Expression.input_names(combobox.filter) ++
          Expression.input_names(argument_values(combobox))
      )

    validate_inputs!(inputs, combobox, context)
    %{combobox | __inputs__: inputs}
  end

  defp primary_read!(resource, combobox, context) do
    case Ash.Resource.Info.primary_action(resource, :read) do
      %{name: name} ->
        name

      _ ->
        Error.raise!(
          module: context.module,
          location: Entity.anno(combobox),
          path: input_path(context, combobox, :read_action),
          why:
            "combobox #{inspect(combobox.name)} has no `read_action`, and " <>
              "#{inspect(resource)} has no primary read action",
          fix: "set `read_action`, or declare a primary read action on #{inspect(resource)}"
        )
    end
  end

  defp validate_read_action!(resource, name, combobox, context) do
    case Ash.Resource.Info.action(resource, name) do
      %{type: :read} = action ->
        action

      %{type: type} ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(combobox, :read_action) || Entity.anno(combobox),
          path: input_path(context, combobox, :read_action),
          why:
            "read_action #{inspect(name)} of #{inspect(resource)} is a #{inspect(type)} action",
          fix: "use a read action"
        )

      nil ->
        reads =
          resource
          |> Ash.Resource.Info.actions()
          |> Enum.filter(&(&1.type == :read))
          |> Enum.map(& &1.name)

        Error.raise!(
          module: context.module,
          location: Entity.property_anno(combobox, :read_action) || Entity.anno(combobox),
          path: input_path(context, combobox, :read_action),
          why: "read_action #{inspect(name)} does not exist on #{inspect(resource)}",
          suggestions: Error.did_you_mean(name, reads)
        )
    end
  end

  defp argument_values(combobox), do: Enum.map(combobox.arguments, & &1.value)

  defp validate_arguments!(resource, action, combobox, context) do
    names = Enum.map(action.arguments, & &1.name)

    for argument <- combobox.arguments, argument.name not in names do
      Error.raise!(
        module: context.module,
        location: Entity.anno(argument) || Entity.anno(combobox),
        path: input_path(context, combobox, :argument),
        why:
          "#{inspect(argument.name)} is not an argument of #{inspect(resource)}.#{action.name}. " <>
            "Arguments: #{inspect(names)}",
        suggestions: Error.did_you_mean(argument.name, names)
      )
    end

    given = Enum.map(combobox.arguments, & &1.name)

    for {name, [_, duplicate | _]} <- Enum.group_by(combobox.arguments, & &1.name) do
      Error.raise!(
        module: context.module,
        location: Entity.anno(duplicate) || Entity.anno(combobox),
        path: input_path(context, combobox, :argument),
        why:
          "combobox #{inspect(combobox.name)} gives the argument #{inspect(name)} more than once",
        fix: "keep one `argument #{inspect(name)}`"
      )
    end

    missing =
      for argument <- action.arguments,
          argument.allow_nil? == false,
          is_nil(argument.default),
          argument.name not in given,
          do: argument.name

    if missing != [] do
      Error.raise!(
        module: context.module,
        location: Entity.anno(combobox),
        path: input_path(context, combobox, :argument),
        why:
          "#{inspect(resource)}.#{action.name} has required arguments that no `argument` " <>
            "gives: #{inspect(missing)}",
        fix: "add an `argument` for each, for example `argument :#{hd(missing)}, search()`"
      )
    end
  end

  defp validate_search!(_resource, false, _combobox, _context), do: :ok

  defp validate_search!(resource, search, combobox, context) when is_list(search) do
    for name <- search do
      case Ash.Resource.Info.field(resource, name) do
        %{type: type} when type in @string_types ->
          :ok

        nil ->
          Error.raise!(
            module: context.module,
            location: Entity.property_anno(combobox, :search) || Entity.anno(combobox),
            path: input_path(context, combobox, :search),
            why:
              "combobox #{inspect(combobox.name)} searches #{inspect(name)}, which is not a " <>
                "field of #{inspect(resource)}",
            fix:
              "set `search` (and `value_key` for free text) to fields of #{inspect(resource)}. " <>
                "An argument is not stored, so the defaults cannot search it"
          )

        %{type: type} ->
          Error.raise!(
            module: context.module,
            location: Entity.property_anno(combobox, :search) || Entity.anno(combobox),
            path: input_path(context, combobox, :search),
            why:
              "combobox #{inspect(combobox.name)} searches #{inspect(name)}, which is a " <>
                "#{inspect(type)}. The typed text can only match a `:string` or `:ci_string`",
            fix: "set `search` to string fields, or use `^search()` in `filter`"
          )
      end
    end
  end

  defp validate_sort!(resource, sort, combobox, context) do
    if sort == [] do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :sort) || Entity.anno(combobox),
        path: input_path(context, combobox, :sort),
        why: "the `sort` of combobox #{inspect(combobox.name)} is empty",
        fix: "remove `sort` (the default is the label), or give at least one field"
      )
    end

    for {name, _direction} <- sort, is_nil(Ash.Resource.Info.field(resource, name)) do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :sort) || Entity.anno(combobox),
        path: input_path(context, combobox, :sort),
        why:
          "combobox #{inspect(combobox.name)} sorts by #{inspect(name)}, which is not a field of #{inspect(resource)}"
      )
    end

    if combobox.__mode__ == :free_text and elem(hd(sort), 0) != combobox.value_key do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :sort) || Entity.anno(combobox),
        path: input_path(context, combobox, :sort),
        why:
          "free-text combobox #{inspect(combobox.name)} gets the different values of " <>
            "#{inspect(combobox.value_key)}, so its `sort` must start with it",
        fix: "put `#{combobox.value_key}: :asc` first in `sort`"
      )
    end
  end

  defp validate_limit!(%{limit: limit} = combobox, context)
       when not is_integer(limit) or limit < 1 or limit > @max_limit do
    Error.raise!(
      module: context.module,
      location: Entity.property_anno(combobox, :limit) || Entity.anno(combobox),
      path: input_path(context, combobox, :limit),
      why: "the `limit` of combobox #{inspect(combobox.name)} is #{inspect(limit)}",
      fix: "use a limit from 1 to #{@max_limit}"
    )
  end

  defp validate_limit!(_combobox, _context), do: :ok

  defp validate_keys!(resource, combobox, context) do
    for key <- Enum.uniq([combobox.value_key, combobox.label_key]),
        is_nil(Ash.Resource.Info.field(resource, key)) do
      Error.raise!(
        module: context.module,
        location: Entity.anno(combobox),
        path: input_path(context, combobox, :value_key),
        why:
          "combobox #{inspect(combobox.name)} shows #{inspect(key)}, which is not a field " <>
            "of #{inspect(resource)}",
        fix: "set `value_key` and `label_key` to fields of #{inspect(resource)}"
      )
    end
  end

  defp validate_filter!(_resource, %{filter: nil}, _context), do: :ok

  defp validate_filter!(resource, combobox, context) do
    case Expression.parse_refs(resource, combobox.filter) do
      {:ok, _refs} ->
        :ok

      {:error, message} ->
        Error.raise!(
          module: context.module,
          location: Entity.property_anno(combobox, :filter) || Entity.anno(combobox),
          path: input_path(context, combobox, :filter),
          why: "the `filter` of combobox #{inspect(combobox.name)} is invalid: #{message}"
        )
    end
  end

  defp validate_search_used!(combobox, context) do
    used? =
      (is_list(combobox.search) and combobox.search != []) or
        Expression.uses_search?(combobox.filter) or
        Expression.uses_search?(argument_values(combobox))

    if not used? do
      Error.raise!(
        module: context.module,
        location: Entity.anno(combobox),
        path: input_path(context, combobox, :search),
        why: "the typed text does not filter the options of combobox #{inspect(combobox.name)}",
        fix: "remove `search false`, or use `^search()` in `filter` or `argument :name, search()`"
      )
    end
  end

  defp validate_inputs!([], _combobox, _context), do: :ok

  defp validate_inputs!(names, combobox, context) do
    level =
      context
      |> Map.get(:level_inputs, %{})
      |> Map.get(combobox.__full_path__ || [], [])

    for name <- names, name not in level do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(combobox, :filter) || Entity.anno(combobox),
        path: input_path(context, combobox, :filter),
        why:
          "combobox #{inspect(combobox.name)} uses `^input(#{inspect(name)})`, but the form has " <>
            "no input #{inspect(name)} at the same level",
        suggestions: Error.did_you_mean(name, level)
      )
    end
  end

  defp resolve_size(%{size: size} = input, _resource, _attr_info) when size != :auto, do: input

  defp resolve_size(%Input{type: {module, _}} = input, _resource, _attr_info),
    do: %{input | size: module.default_size()}

  defp resolve_size(%module{} = input, _resource, _attr_info) when module in [Combobox, Select],
    do: %{input | size: :name}

  defp resolve_size(%Field{} = field, _resource, attr_info),
    do: %{field | size: field_size(field, attr_info)}

  defp field_size(%{type: type}, _attr) when type in [:textarea, :attachment], do: :prose
  defp field_size(%{type: :checkbox, "__multiple?__": true}, _attr), do: :prose

  defp field_size(%{type: type}, _attr)
       when type in [:date, :time, :number, :boolean, :toggle, :checkbox, :interval],
       do: :term

  defp field_size(%{type: type}, attr_info)
       when type in [:default, :text, :email, :url, :tel, :search, :password],
       do: constraint_size(attr_info)

  defp field_size(_field, _attr), do: :name

  defp constraint_size(%{constraints: constraints}) when is_list(constraints) do
    case Keyword.get(constraints, :max_length) do
      max when is_integer(max) and max <= 10 -> :code
      max when is_integer(max) and max <= 24 -> :term
      max when is_integer(max) and max >= 100 -> :phrase
      _ -> :name
    end
  end

  defp constraint_size(_attr_info), do: :name

  @doc """
  The `belongs_to` a field name is the foreign key of, if any.
  """
  @spec belongs_to_for(Ash.Resource.t(), atom()) ::
          Ash.Resource.Relationships.BelongsTo.t() | nil
  def belongs_to_for(resource, field_name) do
    Enum.find(
      Ash.Resource.Info.relationships(resource),
      &match?(%Ash.Resource.Relationships.BelongsTo{source_attribute: ^field_name}, &1)
    )
  end

  defp maybe_strip_id_label(input, nil), do: input

  defp maybe_strip_id_label(%{name: name, label: label} = input, _belongs_to) do
    name_str = Atom.to_string(name)

    if String.ends_with?(name_str, "_id") and label == default_label(name) do
      stripped = String.replace_suffix(name_str, "_id", "")
      Map.put(input, :label, default_label(stripped))
    else
      input
    end
  end

  defp primary_key_attr(resource) do
    case Ash.Resource.Info.primary_key(resource) do
      [pk] -> pk
      _ -> :id
    end
  end

  defp validate_field_type(%Field{type: type} = field, context) do
    if type in [:combobox, :select] do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(field, :type) || Entity.anno(field),
        path: input_path(context, field, :type),
        why: "`type: #{inspect(type)}` is not a field type",
        fix: "use `#{type} #{inspect(field.name)}` instead of `field #{inspect(field.name)}`"
      )
    end

    if type not in @built_in_field_types do
      Error.raise!(
        module: context.module,
        location: Entity.property_anno(field, :type) || Entity.anno(field),
        path: input_path(context, field, :type),
        why:
          "unknown field type #{inspect(type)} for field #{inspect(field.name)}. " <>
            "Accepted types: #{inspect(@built_in_field_types)}",
        fix: "for an app input type, use `input #{inspect(field.name)}, MyInputType`",
        suggestions: Error.did_you_mean(type, @built_in_field_types)
      )
    end

    field
  end

  defp input_path(context, %module{name: name}, key \\ nil) do
    kind =
      case module do
        Field -> :field
        Combobox -> :combobox
        Select -> :select
        Input -> :input
      end

    Map.get(context, :path_root, [:forms]) ++ [kind, name] ++ List.wrap(key)
  end

  defp default_label(name), do: PyroManiac.Dsl.Transformers.default_label(name)
end

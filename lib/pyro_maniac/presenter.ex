defprotocol PyroManiac.Presenter do
  @moduledoc """
  Protocol for presenting values in PyroManiac views.

  Converts Elixir values into human-readable display strings for data tables,
  cards, wizard review steps, and other display contexts.
  """

  @fallback_to_any true

  @doc """
  Convert a value to a human-readable display string.
  """
  @spec present(t()) :: String.t()
  def present(value)

  @doc """
  Convert a value to a human-readable display string, with scope for timezone conversion.

  DateTime values use `scope.tz` for timezone conversion. Other types ignore scope.
  """
  @spec present(t(), map() | nil) :: String.t()
  def present(value, scope)
end

defimpl PyroManiac.Presenter, for: Atom do
  def present(nil), do: ""
  def present(true), do: "Yes"
  def present(false), do: "No"

  def present(value) do
    value
    |> Atom.to_string()
    |> String.replace("_", " ")
  end

  def present(value, _scope) when value in [nil, true, false], do: present(value)

  def present(value, scope) do
    case scope do
      %{atom_label: labeler} when is_function(labeler, 1) -> labeler.(value)
      _ -> present(value)
    end
  end
end

defimpl PyroManiac.Presenter, for: Decimal do
  def present(dec), do: Decimal.to_string(dec)
  def present(dec, _scope), do: present(dec)
end

defimpl PyroManiac.Presenter, for: Date do
  def present(date), do: Calendar.strftime(date, "%Y-%m-%d")
  def present(date, _scope), do: present(date)
end

defimpl PyroManiac.Presenter, for: DateTime do
  def present(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")

  def present(dt, scope) do
    tz = (scope && Map.get(scope, :tz)) || "Etc/UTC"
    Calendar.strftime(DateTime.shift_zone!(dt, tz), "%Y-%m-%d %H:%M %Z")
  end
end

defimpl PyroManiac.Presenter, for: NaiveDateTime do
  def present(dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M")
  def present(dt, _scope), do: present(dt)
end

defimpl PyroManiac.Presenter, for: List do
  def present(list) do
    Enum.map_join(list, ", ", &PyroManiac.Presenter.present/1)
  end

  def present(list, scope) do
    Enum.map_join(list, ", ", &PyroManiac.Presenter.present(&1, scope))
  end
end

defimpl PyroManiac.Presenter, for: Ash.CiString do
  def present(%{string: string}), do: string || ""
  def present(value, _scope), do: present(value)
end

defimpl PyroManiac.Presenter, for: Ash.NotLoaded do
  def present(_), do: ""
  def present(_, _scope), do: ""
end

defimpl PyroManiac.Presenter, for: Map do
  @display_keys [:name, :label, :title, :code]

  def present(map) do
    case find_display_value(map) do
      {:ok, value} -> to_string(value)
      :error -> fallback(map)
    end
  end

  def present(map, _scope), do: present(map)

  defp find_display_value(map) do
    Enum.find_value(@display_keys, :error, fn key ->
      with {:ok, value} <- Map.fetch(map, key),
           false <- match?(%Ash.NotLoaded{}, value) do
        {:ok, value}
      else
        _ -> nil
      end
    end)
  end

  defp fallback(%{id: id}), do: to_string(id)
  defp fallback(map), do: inspect(map)
end

defimpl PyroManiac.Presenter, for: Any do
  def present(value) do
    case String.Chars.impl_for(value) do
      nil -> inspect(value)
      _ -> to_string(value)
    end
  end

  def present(value, _scope), do: present(value)
end

defmodule PyroManiac.Presenter.Helpers do
  @moduledoc """
  Helper functions used alongside the Presenter protocol.
  """

  @doc """
  Humanize a field name for display.

  Handles both atoms and dot-path binaries like `"department.name"`.
  """
  @spec humanize_field(atom() | String.t()) :: String.t()
  def humanize_field(field) when is_atom(field) do
    field
    |> Atom.to_string()
    |> humanize_field()
  end

  def humanize_field(field) when is_binary(field) do
    field
    |> String.split(".")
    |> List.last()
    |> String.replace("_", " ")
    |> String.capitalize()
  end
end

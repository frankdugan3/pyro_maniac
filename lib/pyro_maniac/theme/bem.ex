defmodule PyroManiac.Theme.BEM do
  @moduledoc """
  A PyroManiac theme implementation for BEM classes. You are expected to provide your own CSS implementation.
  """

  use PyroManiac.Theme

  alias PyroManiac.Theme.BaseClass

  theme do
    prefix "pyromaniac-"

    for class <- BaseClass.default_base_class_names() do
      base_class class,
                 class
                 |> Atom.to_string()
                 |> String.replace(~r/(?<!_)_(?!_)/, "-")
    end
  end
end

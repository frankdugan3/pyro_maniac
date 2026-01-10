# if Code.ensure_loaded?(Hologram) do
#   defmodule PyroManiac.Hologram do
#     @moduledoc """
#     Hologram components to automatically render PyroManiac DSL.
#     """
#     @behaviour PyroManiac.Backend
#
#     use Spark.Dsl,
#       opt_schema: [
#         endpoint: [
#           type: {:behaviour, Phoenix.Endpoint},
#           doc: "Your Phoenix endpoint",
#           required: true
#         ]
#       ],
#       single_extension_kinds: [:theme],
#       default_extensions: [
#         theme: PyroManiac.Theme.DaisyUI,
#         exensions: [PyroManiac.Theme.Dsl]
#       ]
#
#     @type t :: module
#
#     @impl Spark.Dsl
#     def handle_opts(opts) do
#       quote bind_quoted: [resource: opts[:endpoint]] do
#         @persist {:endpoint, endpoint}
#       end
#     end
#
#     @impl PyroManiac.Backend
#     def builder(_) do
#       :ok
#     end
#   end
# end

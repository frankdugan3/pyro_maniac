defmodule PyroManiac.LiveView.Components do
  @moduledoc """
  Base components to render PyroManiac DSL to LiveView.
  """

  use Phoenix.Component

  # import Phoenix.HTML
  import PyroManiac.Helpers

  alias Ash.Page.{Keyset, Offset}
  alias Ash.Resource.Info
  alias Phoenix.LiveView.JS
  # alias Phoenix.HTML.{Form, FormField}
  # alias PyroManiac.Info
  # alias PyroManiac.Theme.BaseClass
  # alias Spark.Dsl.Extension

  alias PyroManiac.{DataTable}

  attr :data_table, DataTable.Action, required: true
  attr :backend, :atom, required: true
  attr :read_result, :map, required: true

  def data_table(assigns) do
    assigns =
      assigns
      |> case do
        %{read_result: {%{results: rows} = page, query}} = assigns ->
          assigns
          |> assign(:rows, rows)
          |> assign(:page, page)
          |> assign(:query, query)

        %{read_result: {rows, query}} = assigns when is_list(rows) ->
          assigns
          |> assign(:rows, rows)
          |> assign(:page, nil)
          |> assign(:query, query)
      end
      |> assign_new(:display, fn -> assigns[:display] || assigns.data_table.default_display end)
      |> assign_new(:sort, fn -> assigns[:sort] || assigns.data_table.default_sort end)
      |> assign_new(:sorts_by_column, fn -> %{} end)

    ~H"""
    <table id={@id} class={class(@data_table, :class, assigns)}>
      <caption class={class(@data_table, :caption_class, assigns)}>{@data_table.label}</caption>
      <thead class={class(@data_table, :header_class, assigns)}>
        <tr class={class(@data_table, :header_row_class, assigns)}>
          <.sort_control
            :for={name <- @display}
            backend={@backend}
            field={@data_table.columns[name]}
            query={@query}
            sorts_by_column={@sorts_by_column}
          />
        </tr>
      </thead>
      <tbody class={class(@data_table, :body_class, assigns)}>
        <tr :for={row <- @rows} class={class(@data_table, :body_row_class, assigns)}>
          <.cell
            :for={name <- @display}
            backend={@backend}
            row={row}
            field={@data_table.columns[name]}
          />
        </tr>
      </tbody>
      <tfoot class={class(@data_table, :footer_class, assigns)}>
        <tr class={class(@data_table, :footer_row_class, assigns)}>
          <td class={class(@data_table, :footer_cell_class, assigns)} colspan={length(@display)}>
            <.pagination backend={@backend} page={@page} query={@query} />
          </td>
        </tr>
      </tfoot>
    </table>
    """
  end

  attr :backend, :atom, required: true
  attr :field, DataTable.Column, required: true, doc: "The field to sort"
  attr :sorts_by_column, :map, required: true, doc: "The current sorts"
  attr :query, Ash.Query, required: true, doc: "The query to sort"
  attr :tag_name, :string, default: "th", doc: "The HTML tag for the sort control"
  attr :component, :atom, default: :data_table, doc: "The component for the base class"

  defp sort_control(%{field: %{keyset_sortable?: false}, page: %Keyset{}} = assigns) do
    ~H"""
    <.dynamic_tag tag_name={@tag_name} class={class(@field, :header_class, assigns)}>
      {@field.label}
    </.dynamic_tag>
    """
  end

  defp sort_control(%{field: %{sortable?: false}} = assigns) do
    ~H"""
    <.dynamic_tag tag_name={@tag_name} class={class(@field, :header_class, assigns)}>
      {@field.label}
    </.dynamic_tag>
    """
  end

  defp sort_control(assigns) do
    ~H"""
    <.dynamic_tag tag_name={@tag_name} class={class(@field, :header_class, assigns)}>
      {@field.label}
    </.dynamic_tag>
    """
  end

  attr :backend, :atom, required: true
  attr :field, DataTable.Column, required: true
  attr :row, :map, required: true
  attr :tag_name, :string, default: "th"

  defp cell(assigns) do
    ~H"""
    <.dynamic_tag tag_name={@tag_name} class={class(@field, :cell_class, assigns)}></.dynamic_tag>
    """
  end

  attr :direction, :atom,
    values: ~W[asc asc_nils_first desc desc_nils_last]a,
    doc: "The direction of the sort"

  attr :position, :integer, doc: "The position of the sort"

  attr :backend, :atom, required: true

  defp sort_icon(%{direction: :asc} = assigns) do
    ~H"""
    <.icon backend={@backend} kind="sort-asc" />
    <sup :if={@position}>{@position}</sup>
    """
  end

  defp sort_icon(%{direction: :asc_nils_first} = assigns) do
    ~H"""
    <.icon backend={@backend} kind="sort-asc-nils-first" />
    <sup :if={@position}>{@position}</sup>
    """
  end

  defp sort_icon(%{direction: :desc} = assigns) do
    ~H"""
    <.icon backend={@backend} kind="sort-desc" />
    <sup :if={@position}>{@position}</sup>
    """
  end

  defp sort_icon(%{direction: :desc_nils_last} = assigns) do
    ~H"""
    <.icon backend={@backend} kind="sort-desc-nils-last" />
    <sup :if={@position}>{@position}</sup>
    """
  end

  @default_page_limit_options [10, 25, 50, 100, 250, 500, 1_000]

  attr :backend, :atom, required: true
  attr :page, :map, required: true
  attr :query, Ash.Query, required: true
  attr :page_limit_options, :list

  def pagination(%{page: %Offset{}} = assigns) do
    assigns =
      assign_new(assigns, :page_limit_options, fn ->
        max_page_size = max_page_size(assigns.query)
        Enum.filter(@default_page_limit_options, &(&1 <= max_page_size))
      end)

    ~H"""
    <div class={class(:base_class, :pagination, assigns)}>
      <div class={class(:base_class, :pagination__navigator, assigns)}>
        <button
          :if={@page.offset}
          class={class(:base_class, :pagination__first, assigns)}
          type="button"
          disabled={!prev_page?(@page)}
          color={if prev_page?(@page), do: "primary", else: "secondary"}
          size="sm"
          title="First Page"
          phx-click={JS.dispatch("pyro-maniac:scroll-to-top") |> JS.push("change-page-number")}
          phx-value-offset={0}
        >
          <.icon backend={@backend} kind="first-page" />
        </button>
        <button
          :if={@page.offset}
          class={class(:base_class, :pagination__previous, assigns)}
          type="button"
          disabled={!prev_page?(@page)}
          title="Previous Page"
          phx-click={JS.dispatch("pyro-maniac:scroll-to-top") |> JS.push("change-page-number")}
          phx-value-offset={max(0, @page.offset - @page.limit)}
        >
          <.icon backend={@backend} kind="previous-page" />
        </button>
        <button
          :if={@page.offset}
          class={class(:base_class, :pagination__next, assigns)}
          type="button"
          disabled={!@page.more?}
          title="Next Page"
          phx-click={JS.dispatch("pyro-maniac:scroll-to-top") |> JS.push("change-page-number")}
          phx-value-offset={@page.offset + @page.limit}
        >
          <.icon backend={@backend} kind="next-page" />
        </button>
        <button
          :if={@page.offset}
          class={class(:base_class, :pagination__last, assigns)}
          type="button"
          disabled={!@page.more?}
          title="Last Page"
          phx-click={JS.dispatch("pyro-maniac:scroll-to-top") |> JS.push("change-page-number")}
          phx-value-offset={page_count(@page) * @page.limit}
        >
          <.icon backend={@backend} kind="last-page" />
        </button>
        <form
          :if={@page.offset}
          phx-change="change-page-limit"
          class={class(:base_class, :pagination__limit, assigns)}
        >
          <input type="hidden" name="pagination_form[handler-id]" />
          <label class={class(:base_class, :pagination__limit_label, assigns)}>
            <span>Limit:</span>
            <select
              class={class(:base_class, :pagination__limit_input, assigns)}
              name="pagination_form[limit]"
            >
              <option selected value={@page.limit}>
                {floor(@page.limit)}
              </option>
              <option :for={limit <- @page_limit_options} value={limit}>
                {floor(limit)}
              </option>
            </select>
          </label>
        </form>
        <span :if={@page.count}>{page_info(@page)}</span>
        <button
          type="button"
          class={class(:base_class, :pagination__reset, assigns)}
          title="Reset Page/Filter/Sort"
          phx-click={JS.dispatch("pyro-maniac:scroll-to-top") |> JS.push("change-page-reset")}
        >
          Reset
        </button>
        <.scroll_to_top backend={@backend} />
      </div>
    </div>
    """
  end

  def pagination(assigns) do
    ~H"""
    NOTHING!!
    """
  end

  attr :backend, :atom, required: true

  def scroll_to_top(assigns) do
    ~H"""
    <script :type={Phoenix.LiveView.ColocatedHook} name=".PyroManiacScrollToTop">
      export default {
        scrollToTop() {
          let scrollContainer = this.el.closest('[data-scroll-body]')

          if (!scrollContainer) {
            scrollContainer = document.documentElement
          }

          scrollContainer.scrollTo({
            top: 0,
            behavior: 'smooth'
          })
        },
        mounted() {
          this.el.addEventListener('click', () => this.scrollToTop())
          this.handleGlobalScroll = () => this.scrollToTop()
          window.addEventListener('pyro-maniac:scroll-to-top', this.handleGlobalScroll)
        },
        destroyed() {
          window.removeEventListener('pyro-maniac:scroll-to-top', this.handleGlobalScroll)
        }
      }
    </script>
    <button
      type="button"
      id="pyro-maniac-scroll-to-top"
      class={class(:base_class, :scroll_to_top, assigns)}
      title="Scroll to top of page"
      phx-hook=".PyroManiacScrollToTop"
    >
      <.icon backend={@backend} kind="go-to-top" />
    </button>
    """
  end

  attr :backend, :atom, required: true
  attr :kind, :string, required: true

  defp icon(assigns) do
    ~H"""
    <span class={class(:base_class, :icon, assigns)}>
      <.icon_svg backend={@backend} kind={@kind} />
    </span>
    """
  end

  attr :backend, :atom, required: true
  attr :kind, :string, required: true

  defp icon_svg(%{kind: "sort-asc"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-square-chevron-up"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M19 2a3 3 0 0 1 3 3v14a3 3 0 0 1 -3 3h-14a3 3 0 0 1 -3 -3v-14a3 3 0 0 1 3 -3zm-6.387 7.21a1 1 0 0 0 -1.32 .083l-3 3l-.083 .094a1 1 0 0 0 .083 1.32l.094 .083a1 1 0 0 0 1.32 -.083l2.293 -2.292l2.293 2.292l.094 .083a1 1 0 0 0 1.32 -1.497l-3 -3z" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "sort-asc-nils-first"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-square-chevrons-up"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M19 2a3 3 0 0 1 3 3v14a3 3 0 0 1 -3 3h-14a3 3 0 0 1 -3 -3v-14a3 3 0 0 1 3 -3zm-6.387 10.21a1 1 0 0 0 -1.32 .083l-3 3l-.083 .094a1 1 0 0 0 .083 1.32l.094 .083a1 1 0 0 0 1.32 -.083l2.293 -2.292l2.293 2.292l.094 .083a1 1 0 0 0 1.32 -1.497l-3 -3zm0 -5a1 1 0 0 0 -1.32 .083l-3 3l-.083 .094a1 1 0 0 0 .083 1.32l.094 .083a1 1 0 0 0 1.32 -.083l2.293 -2.292l2.293 2.292l.094 .083a1 1 0 0 0 1.32 -1.497l-3 -3z" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "sort-desc"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-square-chevron-down"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M19 2a3 3 0 0 1 3 3v14a3 3 0 0 1 -3 3h-14a3 3 0 0 1 -3 -3v-14a3 3 0 0 1 3 -3zm-9.387 8.21a1 1 0 0 0 -1.32 1.497l3 3l.094 .083a1 1 0 0 0 1.32 -.083l3 -3l.083 -.094a1 1 0 0 0 -.083 -1.32l-.094 -.083a1 1 0 0 0 -1.32 .083l-2.293 2.292l-2.293 -2.292z" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "sort-desc-nills-last"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-square-chevrons-down"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M19 2a3 3 0 0 1 3 3v14a3 3 0 0 1 -3 3h-14a3 3 0 0 1 -3 -3v-14a3 3 0 0 1 3 -3zm-9.387 10.21a1 1 0 0 0 -1.32 1.497l3 3l.094 .083a1 1 0 0 0 1.32 -.083l3 -3l.083 -.094a1 1 0 0 0 -.083 -1.32l-.094 -.083a1 1 0 0 0 -1.32 .083l-2.293 2.292l-2.293 -2.292zm0 -5a1 1 0 0 0 -1.32 1.497l3 3l.094 .083a1 1 0 0 0 1.32 -.083l3 -3l.083 -.094a1 1 0 0 0 -.083 -1.32l-.094 -.083a1 1 0 0 0 -1.32 .083l-2.293 2.292l-2.293 -2.292z" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "first-page"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="icon icon-tabler icons-tabler-outline icon-tabler-chevrons-left"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M11 7l-5 5l5 5" /><path d="M17 7l-5 5l5 5" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "previous-page"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="icon icon-tabler icons-tabler-outline icon-tabler-chevron-left"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M15 6l-6 6l6 6" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "next-page"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="icon icon-tabler icons-tabler-outline icon-tabler-chevron-right"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M9 6l6 6l-6 6" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "last-page"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      stroke-width="2"
      stroke-linecap="round"
      stroke-linejoin="round"
      class="icon icon-tabler icons-tabler-outline icon-tabler-chevrons-right"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M7 7l5 5l-5 5" /><path d="M13 7l5 5l-5 5" />
    </svg>
    """
  end

  defp icon_svg(%{kind: "go-to-top"} = assigns) do
    ~H"""
    <svg
      xmlns="http://www.w3.org/2000/svg"
      width="24"
      height="24"
      viewBox="0 0 24 24"
      fill="currentColor"
      class="icon icon-tabler icons-tabler-filled icon-tabler-arrow-big-up-line"
    >
      <path stroke="none" d="M0 0h24v24H0z" fill="none" /><path d="M10.586 3l-6.586 6.586a2 2 0 0 0 -.434 2.18l.068 .145a2 2 0 0 0 1.78 1.089h2.586v5a1 1 0 0 0 1 1h6l.117 -.007a1 1 0 0 0 .883 -.993l-.001 -5h2.587a2 2 0 0 0 1.414 -3.414l-6.586 -6.586a2 2 0 0 0 -2.828 0z" /><path d="M15 20a1 1 0 0 1 .117 1.993l-.117 .007h-6a1 1 0 0 1 -.117 -1.993l.117 -.007h6z" />
    </svg>
    """
  end

  defp max_page_size(%Ash.Query{action: action, resource: resource}) do
    case Info.action(resource, action.name).pagination do
      %{max_page_size: max} when is_integer(max) -> max
      _ -> 250
    end
  end

  @doc """
  PyroManiac merges theme base classes for a given backend with the DSL overrides, which also allow component classes to be functions accepting `assigns`. This helper function handles that case in components:

  ```elixir
  <:col
    :for={col <- display_columns(@data_table.columns, @display)}
    class={class(col.class, col)}>
  ```
  """
  def class(:base_class, key, %{backend: backend} = assigns) do
    class(backend.base_class(key), assigns)
  end

  def class(entity, key, %{backend: backend} = assigns) do
    class([backend.base_class_for(entity, key), Map.fetch!(entity, key)], assigns)
  end

  def class(class, assigns), do: apply_class(class, assigns)

  defp apply_class(class, assigns, acc \\ [])

  defp apply_class(nil, _, acc), do: acc
  defp apply_class("", _, acc), do: acc
  defp apply_class([], _, acc), do: acc

  defp apply_class([class | rest], assigns, acc),
    do: apply_class(rest, assigns, [apply_class(class, assigns) | acc])

  defp apply_class(fun, assigns, acc) when is_function(fun, 1), do: [fun.(assigns) | acc]
  defp apply_class(class, _, acc) when is_binary(class), do: [class | acc]
end

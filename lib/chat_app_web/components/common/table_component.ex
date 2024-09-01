defmodule ChatAppWeb.Components.TableComponent do
  use ChatAppWeb, :live_component

  @page_size 50

  def mount(socket) do
    {:ok, assign(socket,
      sort_by: :name,
      sort_order: :asc,
      editing_rows: %{},
      page: 1
    )}
  end

  def update(%{table_data: table_data} = assigns, socket) do
    socket =
      socket
      |> assign(assigns)
      |> assign(total_pages: ceil(length(table_data) / @page_size))
      |> fetch_page_data()

    {:ok, socket}
  end

  def handle_event("sort", %{"field" => field}, socket) do
    {sort_by, sort_order} = get_sort_params(socket, String.to_atom(field))
    {:noreply, socket |> assign(sort_by: sort_by, sort_order: sort_order, page: 1) |> fetch_page_data()}
  end

  def handle_event("edit_row", %{"id" => id, "field" => field, "value" => value}, socket) do
    id = String.to_integer(id)
    field = String.to_atom(field)

    updated_row = Map.get(socket.assigns.editing_rows, id, %{id: id})
    |> Map.put(field, value)

    new_editing_rows = Map.put(socket.assigns.editing_rows, id, updated_row)

    {:noreply, assign(socket, editing_rows: new_editing_rows)}
  end

  def handle_event("start_edition", %{"id" => id}, socket) do
    id = String.to_integer(id)
    current_row = Enum.find(socket.assigns.table_data, &(&1.id == id))
    new_editing_rows = Map.put(socket.assigns.editing_rows, id, current_row)
    {:noreply, assign(socket, editing_rows: new_editing_rows)}
  end

  def handle_event("save_edition", %{"id" => id}, socket) do
    id = String.to_integer(id)
    updated_row = Map.get(socket.assigns.editing_rows, id)

    if updated_row do
      send(self(), {:update_table_row, updated_row})

      new_data = update_row_in_data(socket.assigns.table_data, updated_row)
      new_editing_rows = Map.delete(socket.assigns.editing_rows, id)

      {:noreply, socket
        |> assign(table_data: new_data, editing_rows: new_editing_rows)
        |> fetch_page_data()}
    else
      {:noreply, socket}
    end
  end

  def handle_event("load_page", %{"page" => page}, socket) do
    {:noreply, socket |> assign(page: String.to_integer(page)) |> fetch_page_data()}
  end

  defp get_sort_params(socket, field) do
    current_sort_by = socket.assigns.sort_by
    current_sort_order = socket.assigns.sort_order

    if field == current_sort_by do
      {field, if(current_sort_order == :asc, do: :desc, else: :asc)}
    else
      {field, :asc}
    end
  end

  defp fetch_page_data(socket) do
    %{sort_by: sort_by, sort_order: sort_order, table_data: data, page: page} = socket.assigns

    sorted_data =
      data
      |> Enum.sort_by(&Map.get(&1, sort_by), sort_order)

    paginated_data =
      sorted_data
      |> Enum.slice(((page - 1) * @page_size)..(page * @page_size - 1))

    assign(socket, paginated_data: paginated_data)
  end

  defp update_row_in_data(data, updated_row) do
    Enum.map(data, fn row ->
      if row.id == updated_row.id, do: updated_row, else: row
    end)
  end

  def render(assigns) do
    ~H"""
    <div class="flex flex-col">
      <div class="overflow-x-auto">
        <div class="inline-block min-w-full">
          <div class="overflow-hidden border border-neutral-200 rounded-md">
            <table class="min-w-full divide-y divide-neutral-200/70">
              <thead>
                <tr class="text-neutral-800 bg-neutral-200">
                  <%= for {field, label} <- [name: "Name", age: "Age", address: "Address"] do %>
                    <th class={"px-5 py-3 text-xs text-left uppercase cursor-pointer" <> if @sort_by == field, do: " font-bold", else: " font-medium"} phx-click="sort" phx-value-field={field} phx-target={@myself}>
                      <%= label %>
                      <%= if @sort_by == field do %>
                        <%= if @sort_order == :asc, do: "▲", else: "▼" %>
                      <% end %>
                    </th>
                  <% end %>
                  <th class="px-5 py-3 text-xs font-medium text-right uppercase">Action</th>
                </tr>
              </thead>
              <tbody class="divide-y divide-neutral-200/70" id="table-body" phx-update="replace">
                <%= for {row, index} <- Enum.with_index(@paginated_data) do %>
                  <tr id={"row-#{row.id}"} class={"text-neutral-800 #{if rem(index, 2) == 0, do: "bg-neutral-50", else: ""}"}>
                    <%= for field <- [:name, :age, :address] do %>
                      <td class="px-5 py-3 text-sm whitespace-nowrap">
                        <%= if Map.has_key?(@editing_rows, row.id) do %>
                          <input
                            type="text"
                            value={Map.get(@editing_rows[row.id], field, Map.get(row, field))}
                            phx-blur="edit_row"
                            phx-value-id={row.id}
                            phx-value-field={field}
                            phx-target={@myself}
                            class="w-full bg-transparent border-none focus:outline-none focus:ring-0"
                          />
                        <% else %>
                          <%= Map.get(row, field) %>
                        <% end %>
                      </td>
                    <% end %>
                    <td class="px-5 py-4 text-sm font-medium text-right whitespace-nowrap">
                      <%= if Map.has_key?(@editing_rows, row.id) do %>
                        <button class="text-blue-600 hover:text-blue-700" phx-click="save_edition" phx-value-id={row.id} phx-target={@myself}>Save</button>
                      <% else %>
                        <button class="text-blue-600 hover:text-blue-700" href="#" phx-click="start_edition" phx-value-id={row.id} phx-target={@myself}>Edit</button>
                      <% end %>
                    </td>
                  </tr>
                <% end %>
              </tbody>
            </table>
          </div>
        </div>
      </div>
      <div class="flex justify-between items-center mt-4">
        <div>
          Showing page <%= @page %> of <%= @total_pages %>
        </div>
        <div>
          <%= if @page > 1 do %>
            <button class="px-3 py-1 text-sm bg-blue-500 text-white rounded" phx-click="load_page" phx-value-page={@page - 1} phx-target={@myself}>Previous</button>
          <% end %>
          <%= if @page < @total_pages do %>
            <button class="px-3 py-1 text-sm bg-blue-500 text-white rounded ml-2" phx-click="load_page" phx-value-page={@page + 1} phx-target={@myself}>Next</button>
          <% end %>
        </div>
      </div>
    </div>
    """
  end
end

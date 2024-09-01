defmodule ChatAppWeb.UsersLive do
  use ChatAppWeb, :live_view

  alias Faker.Person
  alias Faker.Address

  def mount(_params, _session, socket) do
    {:ok, assign(socket, table_data: initial_data())}
  end

  def handle_info({:update_table_row, updated_row}, socket) do
    IO.inspect(updated_row)
    new_data = update_row_in_data(socket.assigns.table_data, updated_row)
    {:noreply, assign(socket, table_data: new_data)}
  end

  def render(assigns) do
    ~H"""
    <div>
      <.live_component
        module={ChatAppWeb.Components.TableComponent}
        id="my-table"
        table_data={@table_data}
      />
    </div>
    """
  end

  defp initial_data do
    1..100000
    |> Enum.map(fn id ->
      %{
        id: id,
        name: Person.name(),
        age: :rand.uniform(100),
        address: Address.street_address()
      }
    end)
  end

  defp update_row_in_data(data, updated_row) do
    Enum.map(data, fn row ->
      if row.id == updated_row.id, do: updated_row, else: row
    end)
  end
end

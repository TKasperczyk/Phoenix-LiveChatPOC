defmodule ChatAppWeb.ChatRoomLive do
  use ChatAppWeb, :live_view

  import Ecto.Query

  alias ChatApp.Repo
  alias ChatAppWeb.Presence
  alias ChatApp.Accounts.User

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ChatAppWeb.Endpoint.subscribe("room:lobby")

      {:ok, _} = Presence.track(
        self(),
        "room:lobby",
        socket.assigns.current_user.id,
        %{
          username: socket.assigns.current_user.id,
          online_at: inspect(System.system_time(:second))
        }
      )
    end

    users = User |> select([:id]) |> Repo.all() |> Enum.map(& &1.id)
    {:ok, assign(socket, users: users, messages: [], online_users: %{}, selected_user: nil, message: "")}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    if socket.assigns.selected_user do
      ChatAppWeb.Endpoint.broadcast("room:lobby", "new_msg", %{body: message, user: socket.assigns.current_user.id, to: socket.assigns.selected_user})
      {:noreply, assign(socket, message: "")}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_event("select_user", %{"user" => user}, socket) do
    {:noreply, assign(socket, selected_user: user)}
  end

  @impl true
  def handle_info(%{event: "new_msg", payload: %{body: body, user: user, to: to}}, socket) do
    {:noreply, Phoenix.Component.update(socket, :messages, fn messages -> [%{user: user, body: body, to: to} | messages] end)}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    {:noreply, socket |> update_presence(diff)}
  end

  defp update_presence(socket, _diff) do
    online_users = Presence.list("room:lobby")
      |> Enum.map(fn {_user_id, data} ->
        List.first(data[:metas])[:username]
      end)
      |> Enum.uniq()

    assign(socket, :online_users, online_users)
  end
end

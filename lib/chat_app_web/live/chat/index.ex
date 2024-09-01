defmodule ChatAppWeb.ChatLive do
  use ChatAppWeb, :live_view

  import Ecto.Query

  alias ChatApp.Repo
  alias ChatAppWeb.Presence
  alias ChatApp.Accounts.User
  alias ChatApp.Chat.ChatMessage
  # alias ChatApp.Chat.Chat

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      ChatAppWeb.Endpoint.subscribe("room:lobby")

      {:ok, _} =
        Presence.track(
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
    # Chat |> select([:id, :name]) |> Repo.all()
    rooms = []

    {:ok,
     assign(socket,
       users: users,
       rooms: rooms,
       messages: [],
       online_users: %{},
       selected_user: nil,
       selected_room: nil,
       message: ""
     )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    cond do
      socket.assigns.selected_user ->
        create_and_broadcast_message(socket, message, recipient_id: socket.assigns.selected_user)

      socket.assigns.selected_room ->
        create_and_broadcast_message(socket, message, room_id: socket.assigns.selected_room)

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_event("select_user", %{"user" => user}, socket) do
    messages = load_messages(socket.assigns.current_user.id, user)

    {:noreply,
     socket
     |> assign(selected_user: user, selected_room: nil, messages: messages)
     |> push_event("focus_input", %{})}
  end

  @impl true
  def handle_event("select_room", %{"room" => room}, socket) do
    messages = load_room_messages(room)

    {:noreply,
     socket
     |> assign(selected_room: room, selected_user: nil, messages: messages)
     |> push_event("focus_input", %{})}
  end

  @impl true
  def handle_info(%{event: "new_msg", payload: %{id: id}}, socket) do
    message = Repo.get(ChatMessage, id) |> Repo.preload(:author)

    {:noreply,
     Phoenix.Component.update(socket, :messages, fn messages -> [message | messages] end)}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    {:noreply, socket |> update_presence(diff)}
  end

  @impl true
  def handle_info({:emoji_selected, emoji}, socket) do
    new_message = socket.assigns.message <> emoji

    {:noreply,
     socket
     |> assign(message: new_message)
     |> push_event("focus_input", %{})}
  end

  defp update_presence(socket, _diff) do
    online_users =
      Presence.list("room:lobby")
      |> Enum.map(fn {_user_id, data} ->
        List.first(data[:metas])[:username]
      end)
      |> Enum.uniq()

    assign(socket, :online_users, online_users)
  end

  defp create_and_broadcast_message(socket, message, attrs) do
    attrs = Enum.into(attrs, %{})
    attrs = Map.merge(attrs, %{contents: message, author_id: socket.assigns.current_user.id})

    case Repo.insert(ChatMessage.changeset(%ChatMessage{}, attrs)) do
      {:ok, chat_message} ->
        ChatAppWeb.Endpoint.broadcast("room:lobby", "new_msg", %{id: chat_message.id})
        {:noreply, assign(socket, message: "")}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  defp load_messages(current_user_id, other_user_id) do
    ChatMessage
    |> where(
      [m],
      (m.author_id == ^current_user_id and m.recipient_id == ^other_user_id) or
        (m.author_id == ^other_user_id and m.recipient_id == ^current_user_id)
    )
    |> order_by([m], desc: m.inserted_at)
    |> limit(50)
    |> Repo.all()
    |> Repo.preload(:author)
  end

  defp load_room_messages(room_id) do
    ChatMessage
    |> where([m], m.room_id == ^room_id)
    |> order_by([m], desc: m.inserted_at)
    |> limit(50)
    |> Repo.all()
    |> Repo.preload(:author)
  end
end

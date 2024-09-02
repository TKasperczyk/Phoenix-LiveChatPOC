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
      ChatAppWeb.Endpoint.subscribe("room:chat")
      ChatAppWeb.Endpoint.subscribe("user:#{socket.assigns.current_user.id}")

      {:ok, _} =
        Presence.track(
          self(),
          "room:chat",
          socket.assigns.current_user.id,
          %{
            username: socket.assigns.current_user.id,
            online_at: inspect(System.system_time(:second))
          }
        )
    end

    users = User |> select([:id, :email, :avatar]) |> Repo.all() |> Enum.map(& %{id: &1.id, username: &1.email, avatar: &1.avatar})
    rooms = []

    {:ok,
     assign(socket,
       users: users,
       rooms: rooms,
       messages: [],
       online_users: %{},
       selected_user_id: nil,
       selected_room_id: nil,
       message: "",
       subscribed_ids: []
     )}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    cond do
      socket.assigns.selected_user_id ->
        create_and_broadcast_message(socket, message,
          recipient_id: socket.assigns.selected_user_id
        )

      socket.assigns.selected_room_id ->
        create_and_broadcast_message(socket, message, room_id: socket.assigns.selected_room_id)

      true ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_event("select_user", %{"user" => user_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/chat?user_id=#{user_id}")}
  end

  @impl true
  def handle_event("select_room", %{"room" => room_id}, socket) do
    {:noreply, push_patch(socket, to: ~p"/chat?room_id=#{room_id}")}
  end

  @impl true
  def handle_info(%{event: "new_msg", payload: %{id: id}}, socket) do
    message = Repo.get(ChatMessage, id) |> Repo.preload(:author)

    if message_viewable_by_user?(message, socket.assigns.current_user.id) do
      new_messages = update_messages_if_relevant(message, socket)
      {:noreply, assign(socket, messages: new_messages)}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    new_messages = update_messages_if_relevant(message, socket)
    {:noreply, assign(socket, messages: new_messages)}
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    {:noreply, socket |> update_presence(diff)}
  end

  @impl true
  def handle_info({:emoji_selected, emoji}, socket) do
    new_message = socket.assigns.message <> emoji
    {:noreply, assign(socket, message: new_message)}
  end

  @impl true
  def handle_params(params, _url, socket) do
    cond do
      user_id = params["user_id"] ->
        handle_user_selection(socket, user_id)

      room_id = params["room_id"] ->
        # Room functionality is not yet implemented
        {:noreply, assign(socket, selected_room_id: room_id, selected_user_id: nil, messages: [])}

      true ->
        {:noreply, socket}
    end
  end

  defp handle_user_selection(socket, user_id) do
    user_id = String.to_integer(user_id)
    if Enum.any?(socket.assigns.users, fn user -> user.id == user_id end) do
      messages = load_messages(socket.assigns.current_user.id, user_id)
      {:noreply, assign(socket, selected_user_id: user_id, selected_room_id: nil, messages: messages)}
    else
      {:noreply, socket}
    end
  end

  defp update_presence(socket, _diff) do
    online_users =
      Presence.list("room:chat")
      |> Enum.map(fn {_user_id, data} ->
        List.first(data[:metas])[:username]
      end)
      |> Enum.uniq()

    assign(socket, :online_users, online_users)
  end

  defp create_and_broadcast_message(socket, message, attrs) do
    sanitized_message = HtmlSanitizeEx.basic_html(message)

    attrs = Enum.into(attrs, %{})

    attrs =
      Map.merge(attrs, %{contents: sanitized_message, author_id: socket.assigns.current_user.id})

    case Repo.insert(ChatMessage.changeset(%ChatMessage{}, attrs)) do
      {:ok, chat_message} ->
        chat_message = Repo.preload(chat_message, :author)
        broadcast_new_message(chat_message)
        {:noreply, socket |> assign(message: "")}

      {:error, _changeset} ->
        {:noreply, socket}
    end
  end

  defp broadcast_new_message(chat_message) do
    payload = %{id: chat_message.id}

    if chat_message.recipient_id do
      ChatAppWeb.Endpoint.broadcast("user:#{chat_message.author_id}", "new_msg", payload)
      ChatAppWeb.Endpoint.broadcast("user:#{chat_message.recipient_id}", "new_msg", payload)
    else
      ChatAppWeb.Endpoint.broadcast("room:#{chat_message.room_id}", "new_msg", payload)
    end
  end

  defp update_messages_if_relevant(message, socket) do
    cond do
      socket.assigns.selected_user_id &&
          (message.author_id == socket.assigns.selected_user_id ||
             message.recipient_id == socket.assigns.selected_user_id) ->
        [message | socket.assigns.messages]
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Enum.take(50)

      socket.assigns.selected_room_id &&
          message.room_id == socket.assigns.selected_room_id ->
        [message | socket.assigns.messages]
        |> Enum.sort_by(& &1.inserted_at, {:desc, NaiveDateTime})
        |> Enum.take(50)

      true ->
        socket.assigns.messages
    end
  end

  defp message_viewable_by_user?(message, user_id) do
    cond do
      message.recipient_id &&
          (message.author_id == user_id ||
             message.recipient_id == user_id) ->
        true

      message.room_id ->
        room = Repo.get(ChatRoom, message.room_id)
        room && (room.public? || user_in_room?(user_id, message.room_id))

      true ->
        false
    end
  end

  defp load_messages(current_user_id, other_user_id) do
    ChatMessage
    |> where([m],
      (m.author_id == ^current_user_id and m.recipient_id == ^other_user_id) or
      (m.author_id == ^other_user_id and m.recipient_id == ^current_user_id)
    )
    |> order_by([m], desc: m.inserted_at)
    |> limit(50)
    |> preload(:author)
    |> Repo.all()
  end

  defp user_in_room?(_user_id, _room_id) do
    # Implement this function to check if the user is a member of the room
    # This could involve checking a user_rooms join table or similar
    # Return true if the user is in the room, false otherwise
  end
end

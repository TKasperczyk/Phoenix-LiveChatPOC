defmodule ChatAppWeb.ChatLive do
  use ChatApp.LiveViewWithInvalidation
  use ChatAppWeb, :verified_routes

  alias ChatApp.{Accounts, Chat, PubSub}
  alias ChatAppWeb.{Endpoint, Presence}

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: setup_subscriptions(socket)

    {:ok,
     socket
     |> assign(initial_assigns())
     |> fetch()}
  end

  @impl true
  def handle_params(params, _url, socket) do
    {:noreply, apply_action(socket, socket.assigns.live_action, params)}
  end

  @impl true
  def handle_event("send_message", %{"message" => message}, socket) do
    {:noreply, create_and_broadcast_message(socket, message)}
  end

  @impl true
  def handle_event("update_message", %{"value" => message}, socket) do
    {:noreply, assign(socket, message: message)}
  end

  @impl true
  def handle_event("search_user", %{"value" => username}, socket) do
    {:noreply, assign(socket, search_user: username)}
  end

  @impl true
  def handle_event("select_user", %{"user" => user_id}, socket) do
    {:noreply,
     push_patch(socket, to: ~p"/chat?user_id=#{user_id}")
     |> push_event("focus_message_input", %{})
     |> push_event("scroll_to_bottom", %{})}
  end

  @impl true
  def handle_info({:new_message, message}, socket) do
    new_messages = update_messages_if_relevant(message, socket)

    if new_messages != socket.assigns.messages do
      {:noreply, assign(socket, messages: new_messages) |> push_event("new_message", %{})}
    else
      {:noreply, socket}
    end
  end

  @impl true
  def handle_info(%{event: "presence_diff", payload: diff}, socket) do
    {:noreply, socket |> update_presence(diff)}
  end

  @impl true
  def handle_info({:emoji_selected, emoji}, socket) do
    {:noreply, update(socket, :message, &(&1 <> emoji))}
  end

  def after_fetch(_tag, socket) do
    {:noreply, push_event(socket, "new_message", %{})}
  end

  # Used for receiving new messages on invalidation requests and for receiving the updated message after sending a message
  defp fetch(socket) do
    users = Accounts.list_users()
    messages = load_messages(socket)
    updated_messages = update_read_status(messages, socket.assigns.current_user.id)
    last_read_message_ids = get_last_read_message_ids(users, updated_messages)
    unread_user_ids = Chat.get_unread_user_ids(socket.assigns.current_user.id)

    assign(socket,
      users: users,
      messages: updated_messages,
      last_read_message_ids: last_read_message_ids,
      unread_user_ids: unread_user_ids
    )
  end

  defp apply_action(socket, :index, %{"user_id" => user_id}) do
    handle_user_selection(socket, user_id)
  end

  defp apply_action(socket, :index, _params), do: socket

  defp setup_subscriptions(socket) do
    Endpoint.subscribe("room:chat")
    Endpoint.subscribe("user:#{socket.assigns.current_user.id}")
    PubSub.subscribe("invalidations")

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

  defp get_last_read_message_ids(users, messages) do
    Enum.map(users, fn user ->
      last_read_message =
        messages
        |> Enum.filter(&(&1.read_by_user_ids |> Enum.member?(user.id)))
        |> List.last()

      %{user_id: user.id, message_id: last_read_message && last_read_message.id}
    end)
  end

  defp load_messages(%{assigns: %{selected_user_id: nil}}), do: []

  defp load_messages(%{assigns: %{current_user: current_user, selected_user_id: selected_user_id}}) do
    Chat.get_messages(current_user.id, selected_user_id)
    |> Enum.map(&struct(&1, read_by_user_ids: &1.read_by_user_ids || []))
  end

  defp update_read_status(messages, current_user_id) do
    messages_to_update = Enum.filter(messages, &(current_user_id not in &1.read_by_user_ids))

    Enum.each(messages_to_update, fn msg ->
      Chat.mark_message_as_read(msg.id, current_user_id)
    end)

    Enum.map(messages, fn msg ->
      if current_user_id not in msg.read_by_user_ids do
        %{msg | read_by_user_ids: [current_user_id | msg.read_by_user_ids]}
      else
        msg
      end
    end)
  end

  defp create_and_broadcast_message(socket, message) do
    attrs = %{
      contents: HtmlSanitizeEx.basic_html(message),
      author_id: socket.assigns.current_user.id,
      recipient_id: socket.assigns.selected_user_id
    }

    case Chat.create_message(attrs) do
      {:ok, chat_message} ->
        socket
        |> assign(message: "")
        |> update(:messages, &(&1 ++ [%{chat_message | author: socket.assigns.current_user}]))

      {:error, _changeset} ->
        socket
    end
  end

  defp update_messages_if_relevant(message, socket) do
    if message_relevant?(message, socket) do
      (socket.assigns.messages ++ [message])
      |> Enum.sort_by(& &1.inserted_at, {:asc, NaiveDateTime})
      |> Enum.take(-50)
      |> update_read_status(socket.assigns.current_user.id)
    else
      socket.assigns.messages
    end
  end

  defp message_relevant?(message, socket) do
    socket.assigns.selected_user_id in [message.author_id, message.recipient_id]
  end

  defp update_presence(socket, _diff) do
    online_users =
      Presence.list("room:chat")
      |> Enum.map(fn {_user_id, data} -> List.first(data[:metas])[:username] end)
      |> Enum.uniq()

    assign(socket, :online_users, online_users)
  end

  defp handle_user_selection(socket, user_id) do
    user_id = String.to_integer(user_id)

    if Enum.any?(socket.assigns.users, &(&1.id == user_id)) do
      messages = Chat.get_messages(socket.assigns.current_user.id, user_id)
      updated_messages = update_read_status(messages, socket.assigns.current_user.id)
      last_read_message_ids = get_last_read_message_ids(socket.assigns.users, updated_messages)
      unread_user_ids = Chat.get_unread_user_ids(socket.assigns.current_user.id)

      assign(socket,
        selected_user_id: user_id,
        last_read_message_ids: last_read_message_ids,
        selected_room_id: nil,
        messages: updated_messages,
        unread_user_ids: unread_user_ids
      )
    else
      socket
    end
  end

  defp initial_assigns do
    %{
      rooms: [],
      online_users: %{},
      unread_user_ids: [],
      selected_user_id: nil,
      selected_room_id: nil,
      message: "",
      subscribed_ids: [],
      search_user: "",
      last_read_message_ids: []
    }
  end

  def watched_tags, do: ["users", "chat_messages"]
end

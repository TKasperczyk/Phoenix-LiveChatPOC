defmodule ChatAppWeb.ChatLive do
  use ChatApp.LiveViewWithInvalidation
  use ChatAppWeb, :verified_routes

  alias ChatApp.{Accounts, Chat, PubSub, Cache}
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
  def handle_event("element_visible", %{"id" => id}, socket) do
    case Integer.parse(id) do
      {message_id, _} ->
        current_user_id = socket.assigns.current_user.id

        new_messages = Enum.map(socket.assigns.messages, fn msg ->
          if msg.id == message_id and current_user_id not in msg.read_by_user_ids do
            %{msg | read_by_user_ids: [current_user_id | msg.read_by_user_ids]}
          else
            msg
          end
        end)

        if new_messages != socket.assigns.messages do
          send(self(), {:update_read_status, message_id, current_user_id})
          {:noreply, assign(socket, messages: new_messages)}
        else
          {:noreply, socket}
        end

      :error ->
        {:noreply, socket}
    end
  end

  @impl true
  def handle_event("element_not_visible", %{"id" => _id}, socket) do
    {:noreply, socket}
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

  @impl true
  def handle_info({:update_read_status, message_id, user_id}, socket) do
    Chat.mark_message_as_read(message_id, user_id)
    {:noreply, socket}
  end

  def after_fetch(_tag, socket) do
    {:noreply, push_event(socket, "new_message", %{})}
  end

  defp fetch(socket) do
    users = fetch_cached_or_query("users", fn -> Accounts.list_users() end)
    messages = load_messages(socket)
    assign(socket, users: users, messages: messages)
  end

  defp apply_action(socket, :index, %{"user_id" => user_id}) do
    handle_user_selection(socket, user_id)
  end

  defp apply_action(socket, :index, _params), do: socket

  defp initial_assigns do
    %{
      rooms: [],
      online_users: %{},
      selected_user_id: nil,
      selected_room_id: nil,
      message: "",
      subscribed_ids: [],
      search_user: ""
    }
  end

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

  defp load_messages(%{assigns: %{selected_user_id: nil}}), do: []

  defp load_messages(%{assigns: %{current_user: current_user, selected_user_id: selected_user_id}}) do
    cache_key = Cache.KeyGenerator.generate("chat_messages", current_user.id, recipient_id: selected_user_id)
    fetch_cached_or_query(cache_key, fn ->
      Chat.get_messages(current_user.id, selected_user_id)
      |> Enum.map(&struct(&1, read_by_user_ids: &1.read_by_user_ids || []))
    end)
  end

  defp fetch_cached_or_query(key, query_func) do
    IO.puts("Fetching cached data for key: #{key}")
    case Cache.Manager.get(key) do
      nil ->
        IO.puts("Cache miss for key: #{key}")
        data = query_func.()
        Cache.Manager.set(key, data)
        data
      cached_data ->
        IO.puts("Cache hit for key: #{key}")
        cached_data
    end
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
      assign(socket, selected_user_id: user_id, selected_room_id: nil, messages: messages)
    else
      socket
    end
  end

  def watched_tags, do: ["users", "chat_messages"]
end

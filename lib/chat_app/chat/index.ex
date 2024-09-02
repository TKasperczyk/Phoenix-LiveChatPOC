defmodule ChatApp.Chat do
  import Ecto.Query
  alias ChatApp.Repo
  alias ChatApp.Chat.ChatMessage

  def get_messages(current_user_id, other_user_id) do
    ChatMessage
    |> where([m],
      (m.author_id == ^current_user_id and m.recipient_id == ^other_user_id) or
      (m.author_id == ^other_user_id and m.recipient_id == ^current_user_id)
    )
    |> order_by([m], asc: m.inserted_at)
    |> limit(50)
    |> preload(:author)
    |> Repo.all()
  end

  def create_message(attrs) do
    %ChatMessage{}
    |> ChatMessage.changeset(attrs)
    |> Repo.insert()
    |> case do
      {:ok, message} -> {:ok, Repo.preload(message, :author)}
      error -> error
    end
  end

  def subscribe_to_messages(user_id) do
    Phoenix.PubSub.subscribe(ChatApp.PubSub, "user:#{user_id}")
  end

  def broadcast_message(message) do
    Phoenix.PubSub.broadcast(ChatApp.PubSub, "user:#{message.recipient_id}", {:new_message, message})
    Phoenix.PubSub.broadcast(ChatApp.PubSub, "user:#{message.author_id}", {:new_message, message})
  end
end

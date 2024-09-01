defmodule ChatApp.Chat.ChatMessage do
  use Ecto.Schema
  import Ecto.Changeset

  schema "chat_messages" do
    field :contents, :string
    field :read_by_user_ids, {:array, :id}, default: []

    belongs_to :author, ChatApp.Accounts.User
    belongs_to :recipient, ChatApp.Accounts.User
    #belongs_to :room, ChatApp.Chat.Chat

    timestamps()
  end

  @doc false
  def changeset(chat_message, attrs) do
    chat_message
    # :room_id,
    |> cast(attrs, [:contents, :author_id, :recipient_id, :read_by_user_ids])
    |> validate_required([:contents, :author_id])
    |> validate_recipient_or_room()
    |> foreign_key_constraint(:author_id)
    |> foreign_key_constraint(:recipient_id)
    |> foreign_key_constraint(:room_id)
  end

  defp validate_recipient_or_room(changeset) do
    recipient_id = get_field(changeset, :recipient_id)
    room_id = get_field(changeset, :room_id)

    if is_nil(recipient_id) and is_nil(room_id) do
      add_error(changeset, :base, "Either recipient_id or room_id must be present")
    else
      changeset
    end
  end
end

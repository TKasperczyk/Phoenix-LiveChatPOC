defmodule YourApp.Repo.Migrations.CreateChatMessages do
  use Ecto.Migration

  def change do
    create table(:chat_messages) do
      add :contents, :text, null: false
      add :read_by_user_ids, {:array, :id}, default: []
      add :author_id, references(:users, on_delete: :nilify_all), null: false
      add :recipient_id, references(:users, on_delete: :nilify_all)
      #add :room_id, references(:chat_rooms, on_delete: :nilify_all)

      timestamps()
    end

    create index(:chat_messages, [:author_id])
    create index(:chat_messages, [:recipient_id])
    #create index(:chat_messages, [:room_id])
  end
end

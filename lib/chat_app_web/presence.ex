defmodule ChatAppWeb.Presence do
  use Phoenix.Presence,
    otp_app: :chat_app,
    pubsub_server: ChatApp.PubSub

  alias ChatApp.Accounts

  @impl true
  def fetch(_topic, presences) do
    users = presences |> Map.keys() |> Accounts.get_users_map()

    for {key, %{metas: metas}} <- presences, into: %{} do
      {key, %{metas: metas, user: users[String.to_integer(key)]}}
    end
  end
end

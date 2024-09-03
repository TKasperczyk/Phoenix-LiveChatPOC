defmodule ChatApp.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      ChatAppWeb.Telemetry,
      ChatApp.Repo,
      {DNSCluster, query: Application.get_env(:chat_app, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: ChatApp.PubSub},
      {Finch, name: ChatApp.Finch},
      ChatApp.CacheManager,
      ChatApp.CacheInvalidationService,
      ChatAppWeb.Presence,
      ChatAppWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: ChatApp.Supervisor]

    ChatApp.RepoTelemetry.attach()

    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    ChatAppWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end

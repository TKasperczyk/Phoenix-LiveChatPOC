defmodule ChatApp.CacheManager do
  @moduledoc """
  Manages interactions with the Redis cache.
  """

  @redis_url "redis://localhost:6379"

  def start_link do
    Redix.start_link(@redis_url, name: :redix)
  end

  def child_spec(_) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    }
  end

  def get(key) do
    IO.puts("Getting key #{key}")
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, value} -> :erlang.binary_to_term(value)
      {:error, _} -> nil
    end
  end

  def set(key, value) do
    IO.puts("Setting key #{key}")
    Redix.command(:redix, ["SET", key, :erlang.term_to_binary(value)])
  end

  def delete(key) do
    IO.puts("Deleting key #{key}")
    Redix.command(:redix, ["DEL", key])
  end

  def clear_all do
    Redix.command(:redix, ["FLUSHALL"])
  end
end

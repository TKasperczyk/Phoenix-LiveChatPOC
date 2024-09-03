defmodule ChatApp.Cache.Manager do
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
    case Redix.command(:redix, ["GET", key]) do
      {:ok, nil} -> nil
      {:ok, value} -> :erlang.binary_to_term(value)
      {:error, _} -> nil
    end
  end

  def set(key, value, ttl \\ 3600) do
    Redix.pipeline(:redix, [
      ["SET", key, :erlang.term_to_binary(value)],
      ["EXPIRE", key, ttl]
    ])
  end

  def delete(key) do
    Redix.command(:redix, ["DEL", key])
  end

  def clear_by_pattern(pattern) do
    IO.puts("Clearing cache by pattern: #{pattern}")
    case Redix.command(:redix, ["KEYS", pattern]) do
      {:ok, keys} when is_list(keys) and length(keys) > 0 ->
        IO.puts("Found #{length(keys)} keys matching pattern: #{pattern}")
        Redix.pipeline(:redix, Enum.map(keys, &(["DEL", &1])))
        IO.puts("Deleted #{length(keys)} keys from cache")
      {:ok, _} ->
        IO.puts("No keys found matching pattern: #{pattern}")
        {:ok, keys} = Redix.command(:redix, ["KEYS", "*"])
        IO.puts("All keys: #{inspect(keys)}")
      {:error, reason} ->
        IO.puts("Error while trying to find keys matching pattern: #{pattern}. Reason: #{reason}")
    end
  end
end

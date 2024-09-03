defmodule ChatApp.RepoTelemetry do
  def attach do
    :telemetry.attach(
      "repo-telemetry",
      [:chat_app, :repo, :query],
      &handle_event/4,
      nil
    )
  end

  def handle_event([:chat_app, :repo, :query], _measurements, metadata, _config) do
    %{query: query, source: source, result: result} = metadata

    IO.puts("Checking if invalidation is needed for query")
    IO.inspect(query, label: "Query")
    if should_invalidate?(query, result) do
      tag = get_tag(source)
      IO.puts("Broadcast invalidating tag")
      IO.inspect(tag, label: "Tag")
      ChatApp.PubSub.broadcast_invalidate(tag)
    end
  end

  defp should_invalidate?(query, {:ok, _}) do
    String.starts_with?(query, "INSERT") or
      String.starts_with?(query, "UPDATE") or
      String.starts_with?(query, "DELETE")
  end
  defp should_invalidate?(_, _), do: false

  defp get_tag(source) when is_binary(source), do: source
  defp get_tag(source) when is_atom(source), do: Atom.to_string(source)
  defp get_tag(_), do: "unknown"
end

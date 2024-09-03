defmodule ChatApp.CacheInvalidationService do
  use GenServer
  alias ChatApp.CacheManager

  @refresh_interval :timer.minutes(5)

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{})
  end

  def init(state) do
    schedule_refresh()
    {:ok, state}
  end

  def handle_info(:refresh, state) do
    refresh_cache()
    schedule_refresh()
    {:noreply, state}
  end

  defp schedule_refresh do
    Process.send_after(self(), :refresh, @refresh_interval)
  end

  defp refresh_cache do
    # This is a placeholder. You'll need to implement the logic to refresh all cached data.
    # This could involve fetching fresh data for all tags and updating the cache.
    # For now, we'll just clear the cache to force a refresh on next access.
    CacheManager.clear_all()
  end
end

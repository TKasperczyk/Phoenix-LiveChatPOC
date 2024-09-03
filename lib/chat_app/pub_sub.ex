defmodule ChatApp.PubSub do
  alias Phoenix.PubSub
  alias ChatApp.CacheManager

  def subscribe(topic) do
    PubSub.subscribe(ChatApp.PubSub, topic)
  end

  def broadcast(topic, event) do
    PubSub.broadcast(ChatApp.PubSub, topic, event)
  end

  def broadcast_invalidate(tag) do
    CacheManager.delete(tag)
    broadcast("invalidations", {:invalidate, tag})
  end
end

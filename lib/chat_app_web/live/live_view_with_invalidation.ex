defmodule ChatApp.LiveViewWithInvalidation do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.LiveView, layout: {ChatAppWeb.Layouts, :app}
      import ChatApp.PubSub
      alias ChatApp.CacheManager

      @before_compile ChatApp.LiveViewWithInvalidation

      def handle_invalidate(tag, socket) do
        IO.puts("Invalidating tag #{tag}")
        if tag in watched_tags() do
          userTag = "#{socket.assigns.current_user.id}_#{tag}"
          case CacheManager.get(userTag) do
            nil ->
              IO.puts("Cache miss for tag #{tag}")
              updated_socket = fetch(socket)
              updated_assigns = Map.delete(updated_socket.assigns, :flash)
              CacheManager.set(userTag, updated_assigns)
              after_fetch(userTag, updated_socket)
            cached_data ->
              IO.puts("Cache hit for tag #{tag}")
              {:noreply, assign(socket, cached_data)}
          end
        else
          IO.puts("Non-relevant tag #{tag}")
          {:noreply, socket}
        end
      end

      def after_fetch(_tag, socket), do: {:noreply, socket}

      defoverridable handle_invalidate: 2, after_fetch: 2

      def handle_info({:invalidate, tag}, socket) do
        handle_invalidate(tag, socket)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def watched_tags, do: []
      defoverridable watched_tags: 0
    end
  end
end

defmodule ChatApp.LiveViewWithInvalidation do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.LiveView, layout: {ChatAppWeb.Layouts, :app}
      import ChatApp.PubSub
      alias ChatApp.{Cache}

      @before_compile ChatApp.LiveViewWithInvalidation

      def handle_invalidate(tag, socket) do
        IO.puts("Checking invalidation for tag: #{tag}")
        if tag in watched_tags() do
          IO.puts("Invalidating cache for tag: #{tag}")
          invalidate_cache(tag, socket)
          updated_socket = fetch(socket)
          after_fetch(tag, updated_socket)
        else
          IO.puts("Ignoring invalidation for tag: #{tag}")
          {:noreply, socket}
        end
      end

      def invalidate_cache(tag, socket) do
        user_id = socket.assigns.current_user.id
        pattern = "#{Cache.KeyGenerator.generate("#{tag}", user_id)}*"
        IO.puts("Invalidating cache by pattern: #{pattern}")
        Cache.Manager.clear_by_pattern(pattern)
      end

      def after_fetch(_tag, socket), do: {:noreply, socket}

      defoverridable handle_invalidate: 2, after_fetch: 2, invalidate_cache: 2

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

defmodule ChatApp.LiveViewWithInvalidation do
  defmacro __using__(_opts) do
    quote do
      use Phoenix.LiveView, layout: {ChatAppWeb.Layouts, :app}
      import ChatApp.PubSub

      @before_compile ChatApp.LiveViewWithInvalidation

      def handle_invalidate(tag, socket) do
        if tag in watched_tags() do
          updated_socket = fetch(socket)
          after_fetch(tag, updated_socket)
        else
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

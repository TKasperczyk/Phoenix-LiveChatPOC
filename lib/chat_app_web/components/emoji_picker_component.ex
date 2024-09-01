defmodule ChatAppWeb.Components.EmojiPickerComponent do
  use ChatAppWeb, :live_component

  @emojis [
    "😂", "❤️", "🤣", "👍", "😭", "🙏", "😘", "🥰", "😍", "😊",
    "🎉", "😁", "💕", "🥺", "😅", "☺️", "🔥", "💜", "😆", "💖",
    "😉", "🙄", "💯", "😱", "👏", "😒", "🤗", "🤔", "🤨", "😳",
    "🥴", "😷", "🤷", "😢", "🙃", "💪", "✨", "🤦", "😄", "🥳",
    "😡", "😀", "🤭", "😜", "🤪", "☹️", "🤓", "👀", "💋", "🙈",
    "😬", "✅", "🤤", "🥵", "😴", "😎", "🤘", "🤠", "🤢", "😇",
    "🧐", "🤑", "🌹", "🤯", "💀", "🏃", "💩", "💰", "🤐", "😋",
    "🌚", "🌝", "🖤", "🙊", "😏", "👑", "🎶", "🌟", "🐶", "🍓",
    "🍕", "🏆", "👌", "🤞", "🎂", "🌈", "💡", "🎁", "📸", "🐱",
    "🐾", "👋", "🦋", "🍀", "🎈", "🌞", "🚀", "🍺", "🏠", "📚"
  ]

  def render(assigns) do
    ~H"""
    <div class="relative inline-block" phx-hook="EmojiPicker" id={"emoji-picker-#{@id}"}>
      <button
          phx-click="toggle_emoji_box"
          phx-target={@myself}
          class="p-2 text-gray-500 hover:text-gray-700 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50 rounded-full"
        >
          <svg xmlns="http://www.w3.org/2000/svg" class="h-6 w-6" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M14.828 14.828a4 4 0 01-5.656 0M9 10h.01M15 10h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
      </button>
      <%= if @show_emoji_box do %>
        <div class="absolute left-1/2 transform -translate-x-1/2 -translate-y-full z-10" style="margin-top: -55px">
          <div class="bg-white border border-gray-300 rounded shadow-lg w-[400px] h-[300px] overflow-y-auto p-2">
            <div class="grid grid-cols-5 gap-1">
              <%= for emoji <- @emojis do %>
                <button
                  phx-click="select_emoji"
                  phx-value-emoji={emoji}
                  phx-target={@myself}
                  class="p-1 text-2xl hover:bg-gray-100 focus:outline-none focus:ring-2 focus:ring-blue-500 focus:ring-opacity-50"
                >
                  <%= emoji %>
                </button>
              <% end %>
            </div>
          </div>
          <div class="w-4 h-4 bg-white border-b border-r border-gray-300 transform rotate-45 absolute left-1/2 -translate-x-1/2 -bottom-2"></div>
        </div>
      <% end %>
    </div>
    """
  end

  def mount(socket) do
    {:ok, assign(socket, show_emoji_box: false, emojis: @emojis)}
  end

  def handle_event("toggle_emoji_box", _, socket) do
    {:noreply, assign(socket, show_emoji_box: !socket.assigns.show_emoji_box)}
  end

  def handle_event("select_emoji", %{"emoji" => emoji}, socket) do
    send(self(), {:emoji_selected, emoji})
    {:noreply, assign(socket, show_emoji_box: false)}
  end

  def handle_event("close_emoji_box", _, socket) do
    {:noreply, assign(socket, show_emoji_box: false)}
  end
end

let Chat = {
  mounted() {
    this.scrollToBottom();
    this.handleEvent("new_message", () => this.scrollToBottom());
    this.handleEvent("focus_message_input", () => this.focusChatInput());
    this.handleEvent("scroll_to_bottom", () => this.scrollToBottom());
  },
  scrollToBottom() {
    const chatMessages = document.getElementById("chat-messages");
    chatMessages.scrollTop = chatMessages.scrollHeight;
  },
  focusChatInput() {
    const chatInput = document.getElementById("chat-input");
    chatInput.focus();
  }
};

export default Chat;

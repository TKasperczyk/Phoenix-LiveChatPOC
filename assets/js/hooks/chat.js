let Chat = {
	mounted() {
    this.handleEvent("focus_input", () => {
      document.getElementById("chat-input").focus();
    });
  }
};

export default Chat;

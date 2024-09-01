let EmojiPicker = {
    mounted() {
      this.handleDocumentClick = (e) => {
        if (!this.el.contains(e.target) && this.el.querySelector('.absolute')) {
          this.pushEventTo(this.el, "close_emoji_box", {});
        }
      };
  
      document.addEventListener("click", this.handleDocumentClick);
    },
  
    destroyed() {
      document.removeEventListener("click", this.handleDocumentClick);
    }
  };
  
  export default EmojiPicker;
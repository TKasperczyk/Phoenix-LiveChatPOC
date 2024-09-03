let Visibility = {
	mounted() {
		console.log("here");
		this.observer = new IntersectionObserver(
			(entries) => {
				entries.forEach((entry) => {
					const eventName = entry.isIntersecting
						? "element_visible"
						: "element_not_visible";
					this.pushEvent(eventName, { id: entry.target.getAttribute("visibilityId") });
				});
			},
			{
				root: null,
				rootMargin: "0px",
				threshold: 0.1, // Consider element visible when 10% is in view
			},
		);

		this.observer.observe(this.el);
	},
	destroyed() {
		this.observer.disconnect();
	},
};

export default Visibility;
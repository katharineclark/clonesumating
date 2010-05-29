function Pager() {
	var target = null;
	var pages = new Array();
	var loading = null;

	this.assign = function(target) {
		this.target = document.getElementById(target);
	}

	this.addpage = function(idx,content) {
		if (!this.pages) {
			this.pages = new Array();
		}
		this.pages[idx] = content;
	}

	this.has = function(idx) {
		return this.pages[idx] && this.pages[idx].length ? 1 : 0;
	}

	this.show = function(idx) {
		this.target.innerHTML = this.pages[idx];
		Effect.SlideDown(this.target.id,{duration:2});
	}

	return this;
}

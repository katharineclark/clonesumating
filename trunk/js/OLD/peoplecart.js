

	function getCookie(name) {
		var theCookie = document.cookie;
		var index = theCookie.indexOf(name + '=');
		if (index == -1) return '';
		index = theCookie.indexOf('=', index) + 1; // first character
		var endstr = theCookie.indexOf(';', index);
		if (endstr == -1) endstr = theCookie.length; // last character
		return unescape(theCookie.substring(index, endstr));
	}

function Peoplecart() {
	var cards = new Array();
	var delim = '_-_';


	this.load = function() {
		this.cards = getCookie('peoplecart').split(delim);
		this.updateMenu();
	}
	this.save = function() {
		//document.cookie = 'peoplecart='+escape(this.cards.join(delim))+'; expires=' + m.toGMTString() + ';path=/;domain=.consumating.com;'; // '
		setCookie('peoplecart',this.cards.join(delim));
	}

	this.add = function(handle) {
		if (this.cards.length == 30) {
			InfoBox.draw("Your dance card is full!  Time to start reviewing",'PeopleCart');
		}
		if (this.cards.length > 0) {
			this.cards.unshift(handle);
		} else {
			this.cards = new Array(handle);
		}
		this.save();
		this.updateMenu();
	}
	this.remove = function(handle) {
		for (var i=0;i<this.cards.length;i++) {
			if (this.cards[i] == handle) {
				var foo = this.cards.splice(i,1);
				break;
			}
		}
		this.save();
		this.updateMenu();
	}
	this.next = function() {
		if (this.cards.length == 0) return null;

		var card = null;
		while (!card && this.cards.length) {
			card = this.cards.pop();
		}
		this.save();
		return card;
	}

	this.viewNext = function() {
		var card = this.next();
		if (card && card.length) {
			document.location.href="/profiles/"+card;
		} else {
			InfoBox.draw('You have no people in your queue!  This is like a <i>temporary</i> profile bookmark.  You can flag people to look at later, but not have them permanently added to your Hotlist.  \nClick the \'+\' in the top corner of a profile in search or popularity results to add them to your PeopleCart.<br/><div style="float:left"><b>Before:</b><br/><img src="/img/pc-guide-1.gif"></div><div style="float:right"><b>After:</b><br/><img src="/img/pc-guide-2.gif"></div><br clear="all"/><br clear="all"/>Once you\'ve flagged some people, click the link for "Your Peoplecart" in the nav to step through them!','PeopleCart = People to check out later');
		}
	}

	this.contains = function(handle) {
		for (var i=0;i<this.cards.length;i++) {
			if (this.cards[i] == handle) return true;
		}
		return false;
	}

	this.count = function() {
		return this.cards.length == 1 && !this.cards[0].length ? 0 : this.cards.length;
	}

	this.updateMenu = function() {
		try {
			var c = this.count();
			var t = '';
			if (c == 1) {
				t = 'contains 1 consumater.';
			}else if (c > 1) {
				t = 'contains '+c+' consumaters.';
			}
			document.getElementById('peopleCartCount').innerHTML = t;
		} catch(e) {}
	}


	this.load();

	return this;
}


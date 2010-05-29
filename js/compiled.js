

// IMPORTED FROM xmlhttp.js

            function setCookie(name, value, minutes) {
                var today = new Date();
                if (minutes) {
                    var minutes = new Date(today.getTime() + (minutes * 60 * 1000));
                } else {
                    var minutes = new Date(today.getTime() + 48 * 60 * 60 * 1000);
                }
                if (value != null) {
                    document.cookie=name + '=' + escape(value) + '; expires=' + minutes.toGMTString() + ';path=/;domain=.consumating.com;';
                }
                return document.cookie;
            }
    
            function getCookie(name) {
                var theCookie = document.cookie;
                var index = theCookie.indexOf(name + '=');
                if (index == -1) return '';
                index = theCookie.indexOf('=', index) + 1; // first character
                var endstr = theCookie.indexOf(';', index);
                if (endstr == -1) endstr = theCookie.length; // last character
                return unescape(theCookie.substring(index, endstr));
            }


function getHTTPObject() {
	var xmlhttp;
	try {
		xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
	} catch(e) {
		try {
			xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
		} catch(e) {
			try {
				xmlhttp = new XMLHttpRequest();
			} catch(e) {
				alert("Your browser does not support AJAX protocols required to use this site!");
			}
		}
	}

	return xmlhttp;
}
var http = getHTTPObject(); // We create the HTTP Object

function clearForm(formid) {
	var myform = document.getElementById(formid);
	for ( i = 0; i < myform.elements.length; i++ ) {
		if (myform.elements[i].type == 'checkbox') {
			myform.elements[i].checked = false;
		}  else if (myform.elements[i].type == "text" || myform.elements[i].type == "textarea" || myform.elements[i].type == "hidden" || myform.elements[i].type == "password") {
			myform.elements[i].value = '';
		}else if (myform.elements[i].type == "select-one") {
			myform.elements[i].selectedIndex = 0;
		}
	}
}

function populateForm(formid,xmlobj) {
	// takes an xml object and the id of a form and tries to fill in the form based on the xml

	var myform = document.getElementById(formid);
	var val;
	for ( i = 0; i < myform.elements.length; i++ ) {

		if (myform.elements[i].type == 'checkbox') {
			if (xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild) {
				val = xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild.nodeValue;
			} else {
				val = '';
			}
			if (myform.elements[i].value == val) {
				myform.elements[i].checked = true;
			} else {
				myform.elements[i].checked = false;
			}
		} else if (myform.elements[i].type == "text" || myform.elements[i].type == "textarea" || myform.elements[i].type == "hidden" || myform.elements[i].type == "password") {
			if (xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild) {
				val = xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild.nodeValue;
			} else {
				val = '';
			}
			myform.elements[i].value = val;
		} else if (myform.elements[i].type == "select-one") {
			if (xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild) {
				val = xmlobj.getElementsByTagName(myform.elements[i].name)[0].firstChild.nodeValue;
			} else {
				val = '';
			}

			for (o = 0; o < myform.elements[i].options.length; o++) {
				if (myform.elements[i].options[o].value == val) 
					myform.elements[i].selectedIndex=o;
			}
		}
	}
}

var retry = new Array();
function submitRequest(command,formid,params) {
	var request = "/api";
	var data = 'method='+command;
	if (retries == 0) {
		retry = new Array();
		retry['command'] = command;
	}
	var mode,extra;

	if (typeof(command) == 'string') {
	var cnt=0;
		try {
			var myform = document.getElementById(formid);
		

			// iterate through all the form elemnts
			if (formid.length && myform) {
				for ( i = 0; i < myform.elements.length; i++ ) {
					var name = myform.elements[i].name;
					var type = myform.elements[i].type;
					var value = '';

					if (myform.elements[i].type == 'checkbox') {
						if (myform.elements[i].checked) {
							value = myform.elements[i].value;
						}
					} else if (myform.elements[i].type == "text" || myform.elements[i].type == "textarea" || myform.elements[i].type == "hidden" || myform.elements[i].type == "password") {
						value = myform.elements[i].value;
					} else if (myform.elements[i].type == "select-one") {
						value = myform.elements[i].options[myform.elements[i].selectedIndex].value;
					}

					if (value && name) {
						data = data + '&' + name + '=' + escape(value);
						cnt++;
						//request = request + "&" + name + "=" + escape(value);
					}
				}
			}
		} catch(e){}

		if (params != '') {
			var pairs = params.split('&');
			for (var i=0;i<pairs.length;i++) {
				var ele = pairs[i].split('=');
				data = data + '&' + ele[0] + '=' + escape(ele[1]);
				cnt++;
			}
			//request = request + "&" + params;
		}
		var ts = new Date();
		if (cnt > 3) {
			mode = 'POST';
			extra='?sometime='+ts.getTime();
		} else {
			mode = 'GET';
			extra='?sometime='+ts.getTime()+'&'+data;
			data='';
		}
		retry['mode'] = mode;
		retry['extra'] = extra;
		retry['data'] = data;
	} else {
		// this is a retry
		mode = retry['mode'];
		extra = retry['extra'];
		data = retry['data'];
	}
	try {
		http.open(mode,request+extra,true);
		http.onreadystatechange= handleResponse;
		http.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
		http.send(data);
	} catch(e) {
		alert('Unable to fetch thread data: ' + e);
	}
	return false;
}


var retries = 0;
function handleResponse() {
	var response;
	try {
	if (http && http.readyState && http.readyState == 4) {
		if (http && http.status && http.status == 404) {
			alert('404 not found when trying to access '+url);
		} else if (http && http.status && http.status == 200) {
			results = http.responseXML;
			http = getHTTPObject();
			if (results) {
				retries = 0;
				try {
					var status = results.getElementsByTagName('rsp')[0].getAttribute('stat');
					if (status == "ok") {
						if (results.getElementsByTagName('handler')[0].firstChild) {
							var handler = results.getElementsByTagName('handler')[0].firstChild.nodeValue;
							var jscommand = handler + "(results);";
							eval(jscommand);
						}
					} else if (status == "fail") {
						var error = results.getElementsByTagName('error')[0].getAttribute('msg');
						errorBox(error);
					} else {
						errorBox('Unknown command response: Af937');
					}
				} catch(e) {
					alert('error xhttp XHR1: '+e.message)
				}
			} else {
				retries++;
				setTimeout('submitRequest(retry)',1500);
			}
		}
	}
	}catch(e){
		//alert('error XHR2: '+e.message)
	}
}

function statusMessage(xmlobj) {
	errorBox(xmlobj.getElementsByTagName('message')[0].firstChild.nodeValue);
}

function errorBox (message) {
	scroll(0,0);
	document.getElementById('errorMessage').innerHTML = message;
	document.getElementById('errorHolder').style.display = 'block';
}
                        
function closeError() {
	document.getElementById('errorHolder').style.display='none';
}

function apiRequest(lib,params,handler) {
	if (params.length < 100)
		var type = 'get';
	else
		var type = 'post';

	new Ajax.Request('/api',{
		method:type,
		parameters:'method='+lib+'&'+params,
		onComplete:handler
	});
	return false;
}


// IMPORTED FROM infoBox.js

var theDoc = document;

function InfoBox(content,title) {
	var infoEle=null;
	var t=1;
	var infoTop=0;
	var infoLeft=0;
	var tempcontent='';

	var maxWidth = 400;
	var maxHeight = 360;
	var widthStep = new Array(20,10);
	var heightStep = new Array(18,9);

	var insideHeight=360;
	var insideWidth=400;
	var tobj;

	this.draw = function(content,title,options) {
		this.infoEle=null;
		this.t=1;
		this.infoTop=0;
		this.infoLeft=0;
		this.tempcontent='';
		this.tobj=null;

		document.onkeyup = function(e) {
			if (!e) e = window.event;
			if (e.keyCode == 27) {
				InfoBox.clear();
			}
		};

		if (document.all) {
			this.infoTop = (document.body.scrollTop) + (document.body.clientHeight/2);
			this.infoLeft = (document.body.clientWidth)/2;
		} else {
			insideHeight = maxHeight - 2;
			insideWidth = maxWidth - 5;
			this.infoTop = (window.pageYOffset) + (self.innerHeight/2);
			this.infoLeft = (self.outerWidth)/2;
		}

		if (typeof(content) == 'object' || content.indexOf('object') != -1) {
			this.tobj = content;
			content = '';
		}

		var d = theDoc.createElement('div');
		d.id = 'infoBox';
		d.className = 'infoBox';
		d.style.position='absolute';
		d.style.top = (this.infoTop) + 'px';
		d.style.left = (this.infoLeft) + 'px';
		d.style.width = '0px';
		d.style.height = '0px';
		d.style.background = '#9CF';
		d.style.overflow = 'hidden';
		d.style.zIndex = '999999';
		//d.style.MozOpacity=0.88;

		if (options && options.length) {
			for (var i=0;i<options.length;i++) {
				var o = options[i];
				eval("d.style."+o[0]+"="+o[1]);
			}
		}

				
		theDoc.body.appendChild(d);

		if (title == 'undefined') title = '';

		var c = new Array();
		c.push('<div class="corners" style="border-left: 2px solid #666; border-right: 3px solid #666; background: #9CF; width:'+ (insideWidth) +'px; height: ' + (insideHeight) + 'px;">');
		c.push('<div class="pad10">');
		c.push('<div id="infoBoxClearButton"><a href="#" onclick="InfoBox.clear(); return false;" title="Cancel"><img src="/img/delete_tag.gif" border="0" width="15" height="15"/></a></div>');
		c.push('<div id="infoBoxContent"><h1 class="infoBoxTitle">' + title + '</h1><div id="contentHolder">' + content + '</div></div></div></div>');
		this.tempcontent = c.join('');
		this.infoEle = theDoc.getElementById('infoBox');

		this.widen();
	}

	this.updateContent = function(newcontent) {
		document.getElementById('contentHolder').innerHTML = newcontent;
		return true;
	}

	this.clear = function() {
		this.removeCorners();
		this.collapse();
	}

	this.collapse = function() {
		try {
			var d = new Date();
			var t = d.getTime();
			new Effect.DropOut(this.infoEle);
			setTimeout("try{document.body.removeChild(document.getElementById('infoBox'));document.body.removeChild(document.getElementById('infoHolder'));}catch(e){}",1000);
			return false;
		} catch(e) {}
	}

	this.widen = function() {
		try {
			var w = parseInt(this.infoEle.style.width);
			if (w < maxWidth) {
				var l = parseInt(this.infoEle.style.left);
				w += widthStep[0];
				l -= widthStep[1];
				this.infoEle.style.width = w + 'px';
				this.infoEle.style.left = l + 'px';
			}

			var h = parseInt(this.infoEle.style.height);
			if (h < maxHeight) {
				var tp = parseInt(this.infoEle.style.top);
				h += heightStep[0];
				tp -= heightStep[1];
				this.infoEle.style.height = h + 'px';
				this.infoEle.style.top = tp + 'px';
			}


			if (w < maxWidth || h < maxHeight)
					setTimeout('widenInfoBox()',1);
			else {
				this.infoEle.innerHTML = this.tempcontent;
				if (this.tobj != null) {
					document.getElementById('contentHolder').appendChild(this.tobj);
					this.tobj.style.display='block';
				}
				this.addCorners();
			}
		} catch(e) {}
	}

	this.addCorners = function() {
		// top
		var l = theDoc.createElement('img');
		l.id='infobox_tl';
		l.src="/img/corner-infobox-tl.gif";
		l.style.position='absolute';
		l.style.top=(parseInt(this.infoEle.style.top)-9)+'px';
		l.style.left=(parseInt(this.infoEle.style.left)-1)+'px';
		l.style.zIndex = '9999999';
		l.style.MozOpacity=0.88;
		theDoc.body.appendChild(l);

		var c = theDoc.createElement('img');
		c.id='infobox_tc';
		c.src="/img/corner-infobox-top.gif";
		c.style.position='absolute';
		c.style.top = l.style.top;
		c.style.left = (parseInt(l.style.left)+9)+'px';
		c.style.height='10px';
		c.style.width = (parseInt(this.infoEle.style.width)-12)+'px';
		c.style.zIndex = '9999999';
		c.style.MozOpacity=0.88;
		theDoc.body.appendChild(c);

		var r = theDoc.createElement('img');
		r.id='infobox_tr';
		r.src="/img/corner-infobox-tr.gif";
		r.style.position='absolute';
		r.style.top=l.style.top;
		r.style.left=(parseInt(this.infoEle.style.left)+maxWidth-9)+'px';
		r.style.zIndex = '9999999';
		r.style.MozOpacity=0.88;
		theDoc.body.appendChild(r);

		// bottom
		var l = theDoc.createElement('img');
		l.id='infobox_bl';
		l.src="/img/corner-infobox-bl.gif";
		l.style.position='absolute';
		l.style.top=(parseInt(this.infoEle.style.top)+maxHeight-2)+'px';
		l.style.left=(parseInt(this.infoEle.style.left)-1)+'px';
		l.style.zIndex = '9999999';
		l.style.MozOpacity=0.88;
		theDoc.body.appendChild(l);

		var c = theDoc.createElement('img');
		c.id='infobox_bc';
		c.src="/img/corner-infobox-bottom.gif";
		c.style.position='absolute';
		c.style.top = l.style.top;
		c.style.left = (parseInt(l.style.left)+9)+'px';
		c.style.height='10px';
		c.style.width = (parseInt(this.infoEle.style.width)-12)+'px';
		c.style.zIndex = '9999999';
		c.style.MozOpacity=0.88;
		theDoc.body.appendChild(c);

		var r = theDoc.createElement('img');
		r.id='infobox_br';
		r.src="/img/corner-infobox-br.gif";
		r.style.position='absolute';
		r.style.top=l.style.top;
		r.style.left=(parseInt(this.infoEle.style.left)+maxWidth-9)+'px';
		r.style.zIndex = '9999999';
		r.style.MozOpacity=0.88;
		theDoc.body.appendChild(r);

	}
	this.removeCorners = function() {
		var eles = new Array('tl','tc','tr','bl','bc','br');
		for (var i=0;i<eles.length;i++) {
			theDoc.body.removeChild(theDoc.getElementById('infobox_'+eles[i]));
		}
	}
	return this;
}
function widenInfoBox() {
	InfoBox.widen();
}
function collapseInfoBox() {
	InfoBox.collapse();
}


var InfoBox = new InfoBox(); 


// IMPORTED FROM peoplecart.js



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



// IMPORTED FROM cardtools.js

var PeopleCart = new Peoplecart();
function assignMouseOver() {
	var divs = new Array;
	divs = document.getElementsByTagName('div');

	var dt = new Date();
	for (i = 0; i < divs.length; i++) {
		if (divs[i].className.substring(0,4)=='card') {
			var d = document.createElement('div');
			d.id = divs[i].id+'_prenip';
			if (divs[i].className=='cardmini') {
				stylePlusMini(d,divs[i]);
			} else {
                                stylePlus(d,divs[i]);
			}
			d.style.cursor='pointer';
			if (PeopleCart.contains(divs[i].id)) {
				d.innerHTML='<img id="'+divs[i].id+'_corner" src="/img/pile_dogear.gif?'+divs[i].id+'"/>';
				d.onclick = queueDn;
			} else {
				d.innerHTML='<img id="'+divs[i].id+'_corner" src="/img/pile_undogear.gif?'+divs[i].id+'"/>';
				d.onclick = queueUp;
			}

			divs[i].insertBefore(d,divs[i].childNodes[1]);
		}
	}
}  

function queueUp() {
	var handle = this.id.substr(0,this.id.indexOf('_prenip'));
	PeopleCart.add(handle);
	var d = new Date();
	var t = d.getTime();
	document.getElementById(handle+'_corner').src="/img/pile_dogear.gif?"+handle;
	document.getElementById(handle+'_prenip').onclick=queueDn;
	return false;
}

function queueDn() {
	var handle = this.id.substr(0,this.id.indexOf('_prenip'));
	PeopleCart.remove(handle);
	var d = new Date();
	var t = d.getTime();
	document.getElementById(handle+'_corner').src="/img/pile_undogear.gif?"+handle;
	document.getElementById(handle+'_prenip').onclick=queueUp;
	return false;
}

function styleDogear(d,p) {
	d.style.cssFloat='right';
	d.style.vertialAlign='top';
	d.style.position='absolute';
	d.style.top=(p.style.top-1)+'px';
	d.style.left=(p.style.left+(document.all ? 88 : 90))+'px';
	d.style.width='20px';
	d.style.height='20px';
}
function stylePlus(d,p) {
	d.style.cssFloat='right';
	d.style.vertialAlign='top';
	d.style.position='absolute';
	d.style.top=(p.style.top-1)+'px';
	d.style.left=(p.style.left+(document.all ? 86 : 88))+'px';
	d.style.width='20px';
	d.style.height='20px';
}
function stylePlusMini(d,p) {
        d.style.cssFloat='right';
        d.style.vertialAlign='top';
        d.style.position='absolute';
        d.style.top=(p.style.top-1)+'px';
        d.style.left=(p.style.left+(document.all ? 30 : 32))+'px';
        d.style.width='20px';
        d.style.height='20px';
}


// IMPORTED FROM corners.js

function topCorners(type) {
	var str = '';
	if (navigator.userAgent.indexOf('Gecko') == -1 || navigator.userAgent.indexOf('Safari') > -1) {
		str = '<b class="' + type + ' tl"></b><b class="' + type + ' tr"></b>';
	}
	return str;
}

function bottomCorners(type) {
	var str = '';
	if (navigator.userAgent.indexOf('Gecko') == -1 || navigator.userAgent.indexOf('Safari') > -1) {
		if (navigator.userAgent.indexOf('Safari') > -1) {
			str = '<div>';
		}
		str = str + '<b class="' + type + ' bl"></b><b class="' + type + ' br"></b>';
		if (navigator.userAgent.indexOf('Safari') > -1) {
			str = str + '</div>';
		}
	}
	return str;
}
function roundedCorners(type) {
	var str = '';
	if (navigator.userAgent.indexOf('Gecko') == -1 || navigator.userAgent.indexOf('Safari') > -1) {
		str = '<b class="' + type + ' tl"></b><b class="' + type + ' tr"></b><b class="' + type + ' bl"></b><b class="' + type + ' br"></b>';
	}
	return str;
}


function leafCorners(type) {
	var str = '';
	if (navigator.userAgent.indexOf('Gecko') == -1 || navigator.userAgent.indexOf('Safari') > -1) {
		str = '<b class="' + type + ' tl"></b><b class="' + type + ' br"></b>';
	} 
	return str;
}


function talkCorner() {
	var str = '';
	if (navigator.userAgent.indexOf('Gecko') > -1) {
	 	str = '<b class="bubble"></b>';
	}
	return str;

}


// IMPORTED FROM tips.js

var tagtips = new Array("zombies","tattoos","books","music","film","indierock","cartoons","adultswim","tetris");

var tips = new Array("You can increase your popularity by writing clever answers to <a href='/qow.pl'>the weekly questions</a>.","You can have up to 5 photos displaying on your profile. <a href='/photos.pl'>Add more!</a>","Your popularity is calculated based on how many people give your profile a thumbs-up.","You can remove tags from your profile by clicking the little x next to the tag on your profile.","Have you checked your <a href='/popular/'>popularity</a> lately?","Check out <a href='/popular/'>Today's Top Ten</a>.");

//var promotips = new Array("Find interesting people to <a href='/browse/kissing'>kiss</a>. For free.","Literally hundreds of <a href='/browse/underwear'>fully clothed</a> <a href='/browse/nerd'>nerds</a> inside.","<a href='/qow.pl?question=40'>Sitcom</a>-worthy dates found inside.","OMG, we love your glasses! ","Get tagged at Consumating.com","Join for free and find other weirdos like you today!","<A href='/browse/videogames/f'>Girls who play videogames</a>, now available.","<A href='/browse/zombies'>Zombie lovers</a> apply within.","<a href='/browse/webdesign'>Find a web designer</a> to make out with.");

var promotips = new Array("Find People Who Don't Suck","Join the Bored-at-Work Generation!","Get Tagged at Consumating.com");

var welcometips = new Array("Howdy,","Welcome back,","Hey there,","What's up,","Party, party,");

var toolbartip = new Array("");

function toolbarTip() {
		index = Math.floor(Math.random() * toolbartip.length);
		document.write(toolbartip[index]);
}

function displayTip() {

        index = Math.floor(Math.random() * tips.length);
        document.write(tips[index]);
}


function promoTip() {

        index = Math.floor(Math.random() * promotips.length);
        document.write('<a href="/register.pl">' + promotips[index] + '</a>');

}


function welcomeTip() {

        index = Math.floor(Math.random() * welcometips.length);
        document.write(welcometips[index]);

}


function tagTip() {
        var index = Math.floor(Math.random() * tagtips.length);
		document.getElementById('searchtag').value = tagtips[index];
}

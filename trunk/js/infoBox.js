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

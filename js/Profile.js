function Profile(id) {
	this.id = id;
	this.profileId = id;


	this.thumb = function(type) {
		apiRequest('user.thumb','userId='+this.id+'&direction='+type,null);

		try {
			var up = $('thumbup');
			var down = $('thumbdown');
			if (type == 'U') {
				up.src = "/img/up-on.gif";
				down.src = "/img/down.gif";
			} else {
				up.src = "/img/up.gif";
				down.src = "/img/down-on.gif";
			}
		} catch(e) {}

		return false;
	};

	this.photobling = function(type) {
		apiRequest('user.photobling','userId='+this.id+'&direction='+type,null);

		try {
			var up = $('photoup');
			var down = $('photodown');
			if (type == 'U') {
				up.src = "/img/up-grey-on.gif";
				down.src = "/img/down-grey.gif";
			} else {
				up.src = "/img/up-grey.gif";
				down.src = "/img/down-grey-on.gif";
			}
		} catch(e) {}

		return false;
	};

	this.qowbling = function(rid,type) {
		var f = this.handle_qowbling;
		apiRequest('user.qowbling','userId='+this.id+'&responseId='+rid+'&direction='+type,function(r){f(rid,r);});

		try {
			var up = $('qowup'+rid);
			if (type == 'U') {
				up.src = "/img/up-small-on.gif";
			} else {
				up.src = "/img/up-small.gif";
			}
		} catch(e) {}

		return false;
	};

	this.handle_qowbling = function(rid,r) {
		try {
			var up = document.getElementById('qowupcount'+rid);
			var dn = document.getElementById('qowdowncount'+rid);

			var ups = r.responseXML.getElementsByTagName('up')[0].firstChild.nodeValue;
			var downs = r.responseXML.getElementsByTagName('down')[0].firstChild.nodeValue;
			up.innerHTML = ups;
			dn.innerHTML = downs;
		} catch(e) {}
	};

	this.showPhoto = function(img) {
		if ($('mainphoto')) this.firstPhotoSrc = $('mainphoto').src;

		var im = document.createElement('img');

		var ais = document.getElementsByClassName('activephoto');
		for (var i=0;i<ais.length;i++) {
			ais[i].className = '';
		}
		img.className = 'activephoto';
		var src = img.src;
		src = src.replace(/\/100\//,'/large/');
		im.src = src;
		$('mediaArea').innerHTML = '';
		$('mediaArea').appendChild(im);

		try {
			if (im.src == this.firstPhotoSrc) {
				$('photoblingbar').style.display='block';
			} else {
				$('photoblingbar').style.display='none';
			}
		}catch(e){}

		document.location.href='#thumbs';

		return false;
	};


	this.deleteTag = function(tagId) {
		var o = this;
		apiRequest('user.deleteTag','userId='+this.id+'&tagId='+tagId,function(r){o.handle_deleteTag(tagId,r)});
		return false;
	};

	this.handle_deleteTag = function(tagId,r) {
		if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') == 'ok') {
			var d = document.getElementById('tag'+tagId);
			d.parentNode.removeChild(d);
		}
	};

	this.addTag = function(value) {
		var o = this;
		apiRequest('user.addTag','userId='+this.id+'&tag='+value,function(r){o.handle_addTag(r,o)});
		$('tag_add_busy_area').style.display='inline';
		$('tag_add_form_area').style.display='none';
		return false;
	};
	this.handle_addTag = function(r,obj) {
		var rx = r.responseXML;
		try {
			if (rx.getElementsByTagName('rsp')[0].getAttribute('stat') == 'ok') {
				var id = rx.getElementsByTagName('id')[0].firstChild.nodeValue;
				var value = rx.getElementsByTagName('value')[0].firstChild.nodeValue;
				var userId = rx.getElementsByTagName('userId')[0].firstChild.nodeValue;

				var d = document.createElement('div');
				d.className = 'tag';
				d.id = 'tag'+id;
				var im = document.createElement('img');
				if (userId == currentuserid) {
					im.onclick = function() { obj.deleteTag(id); }
				}
				im.src = '/img/tag_on_blue.gif';
				im.align='absmiddle';
				im.border='0';
				d.appendChild(im);
				d.appendChild(document.createTextNode(' '));

				var a = document.createElement('a');
				a.href='/tags/'+value;
				a.title = value;
				a.innerHTML = value;

				if (userId == currentuserid) {
					tagClassName = 'taglink';
				} else {
					tagClassName = 'othertaglink';
					d.className = 'othertag';
				}
				a.className = tagClassName;

				var nb = document.createElement('nobr');
				nb.appendChild(a);
				d.appendChild(nb);

				if (userId == currentuserid) {
					var tags = document.getElementsByClassName(tagClassName);
					var matched = 0;
					for (var i=0;i<tags.length;i++) {
						var ch = tags[i];
						var n = new Array(ch.innerHTML,value);
						n.sort();
						if (n[1] == ch.innerHTML) {
							ch.parentNode.parentNode.parentNode.insertBefore(d,ch.parentNode.parentNode);
							matched = 1;
							break;
						}
					}
					if (matched != 1) {
						$('selftags').appendChild(d);
					}
				} else {
					$('othertags').insertBefore(d,$('othertags').firstChild);
				}
			} else {
				alert('Add Tag Failed');
				return false;
			}
		} catch(e) {alert('System error adding tag: '+e.message) }
		$('tag').value='';
		$('tag_add_busy_area').style.display='none';
		$('tag_add_form_area').style.display='block';
		$('tag-popup').style.visibility='hidden';
	};

	this.editAnswer = function(id) {
		new CsmInPlaceEditor('qowanswer'+id,'/api',{
			callback: function(form,value) {
				return 'method=user.editAnswerText&id='+id+'&answer='+escape(value);
			},
			externalControl: 'editControl'+id,
			rows: 2
		});
	};

	this.deleteOtherTag = function(tagId) {
		var o = this;
		apiRequest('user.deleteOtherTag','userId='+this.profileId+'&tagId='+tagId,function(r){o.deleteTagInfo(r)});
	};

	this.deleteTagInfo = function(r) {
		try {
			r = r.responseXML;
			if (r.getElementsByTagName('addedBy')[0].firstChild)
				var uid = r.getElementsByTagName('addedBy')[0].firstChild.nodeValue;
			var tid = r.getElementsByTagName('tag')[0].getAttribute('id');
			var tag = r.getElementsByTagName('tag')[0].firstChild.nodeValue;
		} catch(e) { alert(e.message);return };

		var c = new Array();
		c.push("<form method='post'>");
		c.push("<input type='hidden' id='deleteBlockuser' name='blockuser' value='"+uid+"'>");
		c.push("<input type='hidden'  id='deleteBlocktag' name='blocktag' value='"+tag+"'>");
		c.push("<input type='hidden'  id='doBlock' name='doBlock' value='0'>");
		c.push("<input type='hidden'  id='doStop' name='doStop'	value='0'>");
		c.push("<input type='hidden' id='deleteTagId' name='tagId' value='"+tid+"'>");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='return false;' class='infoBoxOptionOn'><div class='ibp'>Remove</div></a>");
		c.push("<div class='infoBoxOptionDesc'>Remove <span class='white'>" + tag + "</span><br/>from your profile.</div></div><BR clear='all' />");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' class='infoBoxOption' id='block' onClick='return toggleBlock();'><div class='ibp'>Block</div></a>");
		c.push("<div class='infoBoxOptionDesc'> Permanently block <span class='white'>" + tag + "</span><br/>from being added to you profile.</div></div><BR clear='all' />");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' class='infoBoxOption' id='stop' onClick='return toggleStop();'><div class='ibp'>Stop</div></a>");
		c.push("<div class='infoBoxOptionDesc'> Stop the person who added this tag from ever tagging you again.</div></div><BR clear='all' />");

		c.push("<div class='infoBoxFooter'><a id='infoBoxOKButton' href='#' class='infoBoxOK' title='OK!'>&nbsp;</a></div>");
		c.push('</form>');
		InfoBox.draw(c.join(''),'Remove A Tag');
		$('infoBoxOKButton').onclick = this.deleteOtherTag_final;
	};

	this.deleteOtherTag_final = function() {
		try {
			var blocktag = $('doBlock').value==1 ? $('deleteBlocktag').value : 0;
			if ($('stop')) 
				var blockuser = $('doStop').value==1 ? $('deleteBlockuser').value : 0;
			var tid = $('deleteTagId').value;
			InfoBox.clear();
			var o = this;
			apiRequest('user.deleteTag','userId='+currentuserid+'&tagId='+tid+'&blockuser='+blockuser+'&blocktag='+blocktag,function(r){o.handle_deleteTag(tagId,r)});
		} catch(e) {}
	};
	
	this.setBehavior = function(itemId,str) {
		new ItemBehavior(itemId,str);
	};

	this.pushQowToTop = function(responseId) {
		var o = this;
		apiRequest('user.changeQowOrder','id='+responseId,function(r){o.handle_pushQowToTop(r,responseId)});
	};
	this.handle_pushQowToTop = function(r,responseId) {
		try {
			if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') == 'ok') {
				var p = document.getElementById('qow'+responseId).parentNode;
				var div = document.getElementById('qow'+responseId).cloneNode(true);

				p.removeChild(document.getElementById('qow'+responseId));

				p.insertBefore(div,p.childNodes[0]);
			} else {
				alert('Oops!  something went wrong.');
			}
		} catch(e) {alert(e.message)}
	};

	this.getItemInfo = function(userId,itemId) {
		if ($('mainphoto')) this.firstPhotoSrc = $('mainphoto').src;
		var o = this;
		apiRequest('item.getInfo','userId='+userId+'&itemId='+itemId,o.handle_getItemInfo);
	};
	this.handle_getItemInfo = function(r) {
		var response = r.responseXML;
		var names = new Array();
		var name;
		var type;
		try {
			if (response.getElementsByTagName('previousOwner')[0].firstChild) {
				names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
				names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
			}
			names['creator'] = response.getElementsByTagName('creator')[0].firstChild.nodeValue;
			names['linkcreator'] = response.getElementsByTagName('linkcreator')[0].firstChild.nodeValue;
			names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;

			name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
			type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
		}catch(e){}
		var c = new Array();
		c.push('<center>');
		c.push('<br />');
		if (type == 'system') {
			c.push('<img src="/img/items/system/'+name+'.gif" width="135" height="135"/><br/>');
		} else {
			c.push('<img src="/img/items/user/'+names['id']+'.gif" width="135" height="135"/><br/>');
		}
		c.push('<h2 class="white">This <span class="blue">' + name + '</span>');
		if (names['previousOwner']) {
			c.push(' was given by <a href="/profiles/'+names['linkpreviousOwner']+'">'+names['previousOwner']+'</a>.');
		} else {
			c.push(' was given by <span class="blue">a secret admirer</span>!');
		};
		c.push('</h2>');

		// disabled for post-valentines, pre-general-item launch
		if (response.getElementsByTagName('ownerId')[0].firstChild.nodeValue==currentuserid) {
			//c.push('<div style="float: left; margin-top: 40px; width: 175px;">');
			//c.push('<a href="#" onClick="submitRequest(\'item.take\',\'\',\'itemId='+names['id']+'\');InfoBox.clear();return false;" class="funbutton">Pocket This<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><BR />');
			//c.push('</div>');
		}
		//c.push('<div style="float: right; margin-top: 40px; width: 175px;">');
		//c.push('<a href="#" onClick="InfoBox.clear(); return false;" class="funbutton">Thanks!<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><br />');
		//c.push('</div>');

		// c.push('It was created by <a href="/profiles/'+names['linkcreator']+'">'+names['creator']+'</a>.<br/>');
		
		c.push('</center>');
		c.push('<br clear="all" />');
		c.push('<br clear="all" />');
		c.push('<br clear="all" />');
		//InfoBox.draw(c.join(''),'Details');
		$('mediaArea').innerHTML = c.join('');
		$('photoblingbar').style.display='none';

	};

	this.getGiveItem = function(itemId) {
		var o = this;
		apiRequest('item.giveInfo','userId='+this.profileId+'&itemId='+itemId,function(r){o.handle_getGiveItem(r)});
	}
	this.handle_getGiveItem = function(r) {
		var response = r.responseXML;
		var names = new Array();
		var name;
		var type;
		var giver;
		var giverId;
		var giverPhotoId;
		var recipientPhotoId;
		try {
			names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;
			names['recipient'] = response.getElementsByTagName('recipient')[0].firstChild.nodeValue;
			names['recipientId'] = response.getElementsByTagName('recipientId')[0].firstChild.nodeValue;
			names['linkrecipient'] = response.getElementsByTagName('linkrecipient')[0].firstChild.nodeValue;
			giver = response.getElementsByTagName('giver')[0].firstChild.nodeValue;
			giverId = response.getElementsByTagName('giverId')[0].firstChild.nodeValue;
			giverPhotoId = response.getElementsByTagName('giverPhotoId')[0].firstChild.nodeValue;
			recipientPhotoId = response.getElementsByTagName('recipientPhotoId')[0].firstChild.nodeValue;
			name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
			type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
		}catch(e){}
		var c = new Array();


		c.push('<br clear="all" />');
		c.push('<center>');
		c.push('<div style="height: 120px;">');
		c.push('<div class="card" style="margin-right: 15px;"><img src="http://img.consumating.com/photos/' + giverId + '/100/' + giverPhotoId + '.jpg" height="100" width="100" border="1" alt="You" /><br /><span class="small">' + giver + '</span></div>');
		if (type == 'system') {
			c.push('<div class="present"><img src="http://img.consumating.com/img/items/system/'+name+'.gif" /><br /><img src="/img/givehand.gif" /></div>');
		} else {
			c.push('<div class="present"><img src="http://img.consumating.com/img/items/user/'+names['id']+'.gif" /><br /><img src="/img/givehand.gif" /></div>');
		}
		c.push('<div class="card"><img src="http://img.consumating.com/photos/' + names['recipientId'] + '/100/' + recipientPhotoId + '.jpg" height="100" width="100" border="1" alt="Your Friend" /><br /><span class="small">' + names['recipient'] + '</span></div>');
		c.push('<br clear="all" />');
		c.push('</div>');

		c.push('<br clear="all" />');
		c.push('<h2 class="white">Do you want to give a <span class="blue">'+name+'</span> to '+names['recipient']+'?</h2>');
		c.push('<br clear="all" />');
		c.push('<div>');
		c.push('<div style="float: left; width: 175px;">');
		c.push('<a href="#" onClick="Profile.giveItem('+names['id']+');InfoBox.clear();return false;" class="funbutton">Yup!<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><BR />');
//submitRequest(\'item.give\',\'\',\'userId='+names['recipientId']+'&itemId='+names['id']+'\');InfoBox.clear();return false;" class="funbutton">Yup!<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><BR />');
			c.push('</div>');
		c.push('<div style="float: left; width: 175px;">');
		c.push('<a href="#" onClick="Profile.cancelGiveItem();InfoBox.clear(); return false;" class="funbutton">Nevermind<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><br />');
		c.push('</div>');
		c.push('</div>');
		c.push('</center>');

		InfoBox.draw(c.join(''),'Give A Present');
	}

	this.cancelGiveItem = function() {
		$('giveDropper').removeChild($('giveDropperImg'));
		return false;
	};

	this.giveItem = function(itemId) {
		var o = this;
		apiRequest('item.give','userId='+this.profileId+'&itemId='+itemId,function(r){o.handle_giveItem()});
		document.getElementById('item'+itemId).parentNode.removeChild(document.getElementById('item'+itemId));
		new Effect.Parallel(
			[	
				new Effect.Scale('giveDropperImg',30,{
					scaleFromCenter: true, 
					scaleMode: 'contents', 
					sync: true,
					originalHeight: 50,
					originalWidth: 50
				})
			],
			{ 
				duration: 2.0,
				afterFinish: function() {
					new Effect.MoveBy('giveDropperImg',0,-50,{duration:2.0,queue:'end'});
					new Effect.MoveBy('giveDropperImg',-295,0,{duration:2.0,queue:'end'});
					new Effect.MoveBy('giveDropperImg',0,50,{duration:2.0,queue:'end'});
					new Effect.Scale('giveDropperImg',300,{ scaleFromCenter: true, scaleMode: 'contents',queue:'end'});
					new Effect.Fade('giveDropperImg',{duration:1.5,queue:'end'});
				}
			}
		);
		return false;
	};
	this.handle_giveItem = function(r) {
		if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') != 'ok') {
			alert('Something went wrong!  Refresh the page and try again.');
		}
		return false;
	};
	
	this.changeTagline = function() {
		document.getElementById('taglinelink').onclick=function(){return false;};
		var tl = document.getElementById('tagline').innerHTML;
		var c = new Array();
		c.push('<input type="text" name="newtagline" id="newtagline" value="'+tl+'"/>');
		c.push(_makeButton('smallblue','Update','#','onclick="Profile.saveTagline();return false;"'));
		c.push('<br clear="all"/>');
		document.getElementById('tagline').innerHTML = c.join('<br/>');
	};
	this.saveTagline = function() {
		var o = this;
		var tl = document.getElementById('newtagline').value;
		document.getElementById('tagline').innerHTML = tl;
		apiRequest('user.saveTagline','tagline='+tl,function(r){o.handle_saveTagline()});
		document.getElementById('taglinelink').onclick=function(){o.changeTagline()};
	};
	this.handle_saveTagline = function(r) {
		if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') != 'ok') {
			alert('Something went wrong!  Refresh the page and try again or contact the Feedback Zombie.');
		}
		return false;
	};

	this.submitNewTopic = function() {
		var t = document.getElementById('newtopic');
		var c = document.getElementById('profileChannel');

		
		if (!t.value.length) { alert('You need to say something if you want to have a conversation!'); return false; }
		if (c.options[c.selectedIndex].value=='0') { alert('Please select a channel for this conversation'); return false; }

		var o = this;
		apiRequest('topic.start','profileChannel=' + c.options[c.selectedIndex].value + '&topic='+encodeURIComponent(t.value),function(r){o.handle_submitNewTopic(r)});

		return false;
	};
	this.handle_submitNewTopic = function(r) {
		try {
			var response = r.responseXML;
			$('topicDisplayArea').style.display='block';
			$('newtopicentry').style.display='none';
			$('topictitle').innerHTML = response.getElementsByTagName('title')[0].firstChild.nodeValue;
			$('topicId').value = response.getElementsByTagName('topicId')[0].firstChild.nodeValue;
			topicId = response.getElementsByTagName('topicId')[0].firstChild.nodeValue;
			offset = 0;
			page = 0;
			lastResponseId = 0;
			responseCount = 0;
			lastpage = 0;
		} catch(e) {alert('handle new error: '+e.message)}
		return false;
	};
	this.closeTopic = function(topicId) {
		var c = new Array();
		c.push("<form method='post'>");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='Profile.closeConversation("+topicId+");InfoBox.clear(); return false;' class='infoBoxOption'><div class='ibp'>Close</div></a>");
		c.push("<div class='infoBoxOptionDesc'>Close this conversation.</div></div><BR clear='all' />");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='InfoBox.clear();return false;' class='infoBoxOption'><div class='ibp'>Cancel</div></a>");
		c.push("<div class='infoBoxOptionDesc'>Don\'t close this conversation.</div></div><BR clear='all' />");

		c.push('</form>');
		InfoBox.draw(c.join(''),'Close Conversation');
		return false;
	};
	this.closeConversation = function(topicId) {
		var o = this;
		apiRequest('topic.close','topicId='+topicId,function(r){o.handle_closeConversation(r)});
	};
	this.handle_closeConversation = function(r) {
		if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') != 'ok') {
			alert('something went wrong!  refresh the page and try again or contact the feedback zombie.');
			return false;
		}
		$('topicDisplayArea').style.display='none';
		$('newtopicentry').style.display='block';
		topicId=0;
		$('topicId').value = 0;
		$('responsesArea').innerHTML = '';
		$('newresponses').innerHTML = '';
		return false;
	};
	
	this.deleteConversation = function(id) {
		var o = this;
		apiRequest('topic.delete','topicId='+id,function(r){o.handle_deleteConversation(r)});
		return true;
	};

	this.removeTopic = function(topicId) {
		var c = new Array();
		c.push("<form method='post'>");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='Profile.deleteConversation("+topicId+");InfoBox.clear(); return false;' class='infoBoxOption'><div class='ibp'>Delete</div></a>");
		c.push("<div class='infoBoxOptionDesc'>Delete this conversation.</div></div><BR clear='all' />");
		c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='InfoBox.clear();return false;' class='infoBoxOption'><div class='ibp'>Cancel</div></a>");
		c.push("<div class='infoBoxOptionDesc'>Don\'t delete this conversation.</div></div><BR clear='all' />");

		c.push('</form>');
		InfoBox.draw(c.join(''),'Delete Conversation');
		return false;
	};
	this.handle_deleteConversation = function(r) {
		var response = r.responseXML;
		try {
			var id = response.getElementsByTagName('id')[0].firstChild.nodeValue;
			var box = document.getElementById('topicbox'+id);
			box.parentNode.removeChild(box);
		} catch(e){alert(e.message)}
		return false;
	};
}

function ItemBehavior(itemId,str) {
	this.id = itemId;
	this.behavior = str;

	this.loadScript = function(filename) {
		var e = document.createElement('script');
		e.src = 'http://'+devimgserver+'/js/toys/'+filename;
		e.type = 'text/javascript';
		document.getElementsByTagName('head')[0].appendChild(e);
	};

	this.setBehavior = function() {
		try {
			var bh = this.behavior.split(',');
			if (bh[0] == 'wallpaper') {
				document.body.style.backgroundImage = "url(/img/items/user/"+bh[1]+".gif)";
				document.body.style.backgroundRepeat = 'repeat';
			} else if (bh[0] == 'border') {
				var ds = document.getElementsByTagName('div');	
				for (var i=0;i<ds.length;i++) {
					if (ds[i].className.indexOf('profile_question') > -1
						|| ds[i].className.indexOf('greyborders') > -1
						|| ds[i].className.indexOf('blueborders') > -1
						|| ds[i].className.indexOf('corners') > -1
						|| ds[i].id == 'tagsmain'
						|| ds[i].id == 'thumbsbox'
						|| ds[i].id == 'hotlisted'
						|| ds[i].id == 'main'
					) {
						ds[i].style.borderColor = bh[1];
					}
				}
			} else if (bh[0] == 'header') {
				this.displayBehavior(bh[1]);
			} else if (bh[0] == 'theme') {
				this.displayBehavior(bh[1]);
			} else {
				var ele = document.getElementById('slotimg'+this.id) || document.getElementById('itemimg'+this.id);
				var f = ele.onclick;
				ele.onclick = function() {
					try {
						if (f) f();
						var player = new mediashower();
						player.load(bh[0],bh[1]);
						$('itemMediaShower').innerHTML = player.show();
						$('pluginShower').style.display='block';
					} catch(e){}
				}
			}
				
		}catch(e){}
		return true;
	};

	this.displayBehavior = function(behavior) {
		if (behavior.indexOf('loadScript') > -1) {
			try{
				eval(behavior);
			}catch(e){alert('error dbh1: '+e.message)}
		} else {
			document.write('<style>'+behavior+'</style>');
		}
	}

	this.showRockyou = function(id) {
		var c = new Array();
		c.push('<embed id="slideshowEmbed" src="http://apps.rockyou.com/rockyou.swf?instanceid='+id+'"');
		c.push(' quality="high"  wmode="transparent" name="flashticker" align="middle" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer"/>');
		$('pluginContent').innerHTML = c.join('');
		$('pluginShower').style.display='block';
		Effect.BlindDown('pluginShower');
	}


	if (!this.behavior) { return false; }
	this.setBehavior();
}

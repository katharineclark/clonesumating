var qt;


function toggleHot(results) {
	var hot = document.getElementById('hot');
	var not = document.getElementById('nothot');
	if (results == "false") {
		hot.style.display = 'none';
		not.style.display = 'block';
	} else if (results == "true") {
		not.style.display = 'none';
		hot.style.display = 'block';
	}
}

function showAddTag() {
	// hide the link and show the form
	var link = document.getElementById('showaddlink');
	var form = document.getElementById('addtag');
	link.style.display = 'none';
	form.style.display = 'block';
	form.style.visibility='visible';
	var tag = document.getElementById('tag');
	tag.value = '';
	tag.focus;

	return false;
}

function showLink() {
	// hide the link and show the form
	var form = document.getElementById('tag_add_form');
	var working = document.getElementById('tag_add_working');
	var tag = document.getElementById('tag');
	tag.value = '';
	form.style.display = 'block';
	working.style.display = 'none';

	return false;
}
function hideLink() {
	// hide the link and show the form
	var form = document.getElementById('tag_add_form');
	var working = document.getElementById('tag_add_working');
	form.style.display = 'none';
	working.style.display = 'block';
	return false;
}

function addTagToProfile() {
	//  do an XML HTTP request to add the new tag to this profile
	submitRequest("user.addTag","tagForm","userId=" + thisprofileid);
	hideLink();
	return false;
}

function tagAdded(xmlobj) {
	// handles new tag.
	showLink();
	submitRequest("user.getTags","","userId=" + thisprofileid);
}

function tagList(xmlobj) {
	// prints out all the tags
	var newval = new Array('<P class="medium">','<P class="medium">');
	var taglist = document.getElementById('owner_tags');
	var addedtaglist = document.getElementById('user_tags');
	var tags = xmlobj.getElementsByTagName('tag');
	var l;
	for (var i=0;i<tags.length;i++) {
		try {
			var s=tags[i].getElementsByTagName('source')[0].firstChild.nodeValue;
			var id=tags[i].getElementsByTagName('tagId')[0].firstChild.nodeValue;
			var v=tags[i].getElementsByTagName('value')[0].firstChild.nodeValue;
			var anon=tags[i].getElementsByTagName('anonymous')[0].firstChild.nodeValue;
			if (anon < 1 && s == 'U') {
				var addedby = tags[i].getElementsByTagName('addedby')[0].firstChild.nodeValue;
				var linkaddedby = tags[i].getElementsByTagName('linkaddedby')[0].firstChild.nodeValue;
			}
		}catch(e){}

		if (s == "O") {
			// this is a tag owned by the current user
			newval[0] = newval[0] + '<a class="profiletag" title="'+v+'" href="/tags/' + v + '">';
			if (thisprofileid == currentuserid)
				newval[0] = newval[0] + '<span class="tagoptions" onClick="return submitRequest(\'user.deleteTag\',\'\',\'tagId=' + id + '&userId=' + thisprofileid + '\');"><img src="http://img.consumating.com/img/delete_tag.gif" border=0 align="bottom" width="15" height="15" alt="[delete]"></span>';
			newval[0] = newval[0] + '&nbsp;' + v + '</a>';
			l=0;
		} else if (s == "U") {
			// this is a tag owned by someone else
			newval[1] = newval[1] + '<a class="profiletag" title="'+v+'" href="/tags/' + v + '">';
			if (thisprofileid == currentuserid)
				newval[1] = newval[1] + '<span class="tagoptions" onClick="return submitRequest(\'user.deleteOtherTag\',\'\',\'tagId=' + id + '&userId=' + thisprofileid + '\');"><img src="http://img.consumating.com/img/delete_tag.gif" border=0 align="bottom" width="15" height="15" alt="[delete]"></span>';
			newval[1] = newval[1] + '&nbsp;' + v + '</a>';
			l=1;
		}

		if (thisprofileid == currentuserid) {
			if (anon < 1 && s == 'U') {
				newval[1] = newval[1] + '<span class="small indent">&uarr;added by <a href="/profiles/'+linkaddedby+'">'+addedby+'</a></span>';
			}
		} else {
			if (anon == -1 && s == 'U') {
				newval[1] = newval[1] + '<span class="small indent">&uarr;added by <a href="/profiles/'+linkaddedby+'">'+addedby+'</a></span>';
			}
		}
	}

	taglist.innerHTML = newval[0] + "</p>";
	addedtaglist.innerHTML = newval[1] + "</P>";
}

function tagDeleted(xmlobj) {
	// handles new tag.
	setTimeout('submitRequest("user.getTags","","userId="+ thisprofileid)',300);
}

function thumb(type) {
	submitRequest("user.thumb","","userId=" + thisprofileid + "&direction=" + type);
	var up = document.getElementById('thumbup');
	var down = document.getElementById('thumbdown');
	if (type == 'U') {
		up.src = "/img/up-on.gif";
		down.src = "/img/down.gif";
	} else {
		up.src = "/img/up.gif";
		down.src = "/img/down-on.gif";
	}
	return false;
}

function thumbed(xmlobj) {
	var up = xmlobj.getElementsByTagName('up')[0].firstChild.nodeValue;
	var down = xmlobj.getElementsByTagName('down')[0].firstChild.nodeValue;

	document.getElementById('up').innerHTML = up;
	document.getElementById('down').innerHTML = down;
}


function handleThumbs() {
	if (http.readyState == 4) {
		results = http.responseText;
		thumbs = document.getElementById('thumbs');
		thumbs.innerHTML = results;
	}
}

function handleUpdated(xmlobj) {
	var qt = "handle";
	var newhandle = xmlobj.getElementsByTagName('handle')[0].firstChild.nodeValue;
	show = document.getElementById(qt + "editable");
	hide = document.getElementById(qt + "mod");
	show.innerHTML = newhandle;
	hide.style.display = 'none';
	show.style.display='block';
}

function taglineUpdated(xmlobj) {
	var qt = "tagline";
	var newtagline = xmlobj.getElementsByTagName('tagline')[0].firstChild.nodeValue;
	show = document.getElementById('tagline');
	hide = document.getElementById('newtagline');
	show.innerHTML = newtagline; 
	hide.style.display = 'none';
	show.style.display='block';
}

function editHandle() {
	handle = document.getElementById('handleeditable');
	handlemod = document.getElementById('handlemod');
	handle.style.display = 'none';
	handlemod.style.display = 'block';
	return false;
}


function editTagline() {
	tagline = document.getElementById('taglineeditable');
	taglinemod = document.getElementById('taglinemod');
	tagline.style.display = 'none';
	taglinemod.style.display = 'block';
	return false;
}

function addTagInfo(userId,tag) {
	var c = new Array();
	c.push("<form method='post'>");
	c.push("<br/><input type='checkbox' class='checkbox' id='addTagValue' name='tagValue' value='"+tag+"'>Add this tag to your profile<br/><input type='button' class='gobutton' style='width:50px' value='Add Tag!' onclick='return addTag()'/>");
	InfoBox.draw(c.join(''),'Add A Tag');
	return false;
}
function addTag() {
	var tagValue = document.getElementById('addTagValue').value;
	submitRequest('user.addTag','','userId='+currentuserid+'&tag='+tagValue);
	InfoBox.clear();
	return false;
}


function toggleBlock() {

	var field = document.getElementById('doBlock');
	var butt = document.getElementById('block');

	if (field.value == 1) {

		field.value=0;
		butt.className='infoBoxOption';
	} else {
		field.value=1;
		butt.className='infoBoxOptionOn';
	}
	return false;
}

function toggleStop() {
        var field = document.getElementById('doStop');
        var butt = document.getElementById('stop');

        if (field.value == 1) {

                field.value=0;
                butt.className='infoBoxOption';
        } else {
                field.value=1;
                butt.className='infoBoxOptionOn';
        }


	return false;
}

function deleteTagInfo(response) {
	try {
		if (!response) response = http.responseText;
		if (response.getElementsByTagName('addedBy')[0].firstChild)
			var uid = response.getElementsByTagName('addedBy')[0].firstChild.nodeValue;
		var tid = response.getElementsByTagName('tag')[0].getAttribute('id');
		var tag = response.getElementsByTagName('tag')[0].firstChild.nodeValue;
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

	c.push("<div class='infoBoxFooter'><a href='#' class='infoBoxOK' title='OK!' onClick='return deleteTag()'>&nbsp;</a></div>");
	c.push('</form>');
	InfoBox.draw(c.join(''),'Remove A Tag');
}



function deleteTag() {
	var blocktag = document.getElementById('doBlock').value==1 ? document.getElementById('deleteBlocktag').value : 0;
	if (document.getElementById('stop')) 
		var blockuser = document.getElementById('doStop').value==1 ? document.getElementById('deleteBlockuser').value : 0;
	var tid = document.getElementById('deleteTagId').value;
	InfoBox.clear();
	return submitRequest('user.deleteTag','','userId='+currentuserid+'&tagId='+tid+'&blockuser='+blockuser+'&blocktag='+blocktag);
}

function addToHotlistBox(userId) {
	var c = new Array();
	c.push("<form method='post'>");
	c.push("<input type='hidden' id='ibuserId' name='userId' value='"+userId+"'/>");
	c.push("<span class='desc'>Enter a note about this person: (optional)<br/>");
	c.push("<textarea id='ibnote' name='note' class='textarea' style='height:110px;overflow-y:no'></textarea><br/>");
	//c.push("<input type='button' class='csm_button' style='width:120px' value='Add to Hot List' onclick='return addToHotlist()'/>");
	c.push("<div class='infoBoxFooter'><a href='#' class='infoBoxOK' title='OK!' onClick='return addToHotlist()'>&nbsp;</a></div>");
	InfoBox.draw(c.join(''),'Note');
}
function addToHotlist(userId) {
	toggleHot('true');
	return submitRequest('user.addToHotList','','userId='+userId);
}

function bling(id,type) {
	url = "/qow.pl/bling?qr=" + id + "&t=" + type;
	http.open("GET",url,true);
	http.onreadystatechange= handleBling;
	http.send(null);
	bid = id;

	if (type == "U") {
		obj = document.getElementById('bling'+bid+"-up");
		obj.src = "/img/up-small-on.gif";
	} else {
		obj = document.getElementById('bling'+bid+"-up");
		obj.src = "/img/up-small.gif";
	}


	return false;
}

function handleBling() {
	if (http.readyState == 4) {
		resultsT = http.responseText;
		var results = new Array();
		results = resultsT.split(';');
		var up = document.getElementById(bid+'Up');
		var dn = document.getElementById(bid+'Dn');

		try {
			if (results[1].split('-')[0] == 'U') {
				up.innerHTML = results[1].split('-')[1];
				dn.innerHTML = results[2].split('-')[1];
			} else {
				up.innerHTML = results[2].split('-')[1];
				dn.innerHTML = results[1].split('-')[1];
			}
		} catch(e) {}
		bid ='';
	}
}

function getItemInfo(userId,itemId) {
	submitRequest('item.getInfo','','userId='+userId+'&itemId='+itemId);
}
function getItemInfo_dynamic() {
	var itemId = this.id;
	var userId = thisprofileid;
	getItemInfo(userId,itemId);
	return false;
}

function getGiveItem_dynamic() {
        var itemId = this.id;
        var userId = thisprofileid;
        getGiveItem(userId,itemId);
        return false;

}
function showItemInfo(response) {
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
	c.push('<img src="/img/items/'+type+'/'+name+'.gif" width="135" height="135"/><br/>');
	c.push('<h2 class="white">This <span class="blue">' + name + '</span>');
	if (names['previousOwner']) {
		c.push(' was given by <a href="/profiles/'+names['linkpreviousOwner']+'">'+names['previousOwner']+'</a>.');
	} else {
		c.push(' was given by <span class="blue">a secret admirer</span>!');
	};
	c.push('</h2>');

	// disabled for post-valentines, pre-general-item launch
	if (response.getElementsByTagName('ownerId')[0].firstChild.nodeValue==currentuserid) {
        c.push('<div style="float: left; margin-top: 40px; width: 175px;">');
        c.push('<a href="#" onClick="submitRequest(\'item.take\',\'\',\'itemId='+names['id']+'\');InfoBox.clear();return false;" class="funbutton">Pocket This<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><BR />');
        c.push('</div>');
	}
	c.push('<div style="float: right; margin-top: 40px; width: 175px;">');
	c.push('<a href="#" onClick="InfoBox.clear(); return false;" class="funbutton">Thanks!<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><br />');
	c.push('</div>');

	// c.push('It was created by <a href="/profiles/'+names['linkcreator']+'">'+names['creator']+'</a>.<br/>');
	
	c.push('</center>');
	InfoBox.draw(c.join(''),'Details');
}
function getGiveItem(userId,itemId) {
	submitRequest('item.giveInfo','','userId='+userId+'&itemId='+itemId);
	return false;
}
function giveItemInfo(response) {
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
	c.push('<div class="present"><img src="http://img.consumating.com/img/items/'+type+'/'+name+'.gif" /><br /><img src="/img/givehand.gif" /></div>');
	c.push('<div class="card"><img src="http://img.consumating.com/photos/' + names['recipientId'] + '/100/' + recipientPhotoId + '.jpg" height="100" width="100" border="1" alt="Your Friend" /><br /><span class="small">' + names['recipient'] + '</span></div>');
	c.push('<br clear="all" />');
	c.push('</div>');

	c.push('<br clear="all" />');
	c.push('<h2 class="white">Do you want to give a <span class="blue">'+name+'</span> to '+names['recipient']+'?</h2>');
	c.push('<br clear="all" />');
	c.push('<div>');
	c.push('<div style="float: left; width: 175px;">');
	c.push('<a href="#" onClick="submitRequest(\'item.give\',\'\',\'userId='+names['recipientId']+'&itemId='+names['id']+'\');InfoBox.clear();return false;" class="funbutton">Yup!<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><BR />');
		c.push('</div>');
	c.push('<div style="float: left; width: 175px;">');
	c.push('<a href="#" onClick="InfoBox.clear(); return false;" class="funbutton">Nevermind<b class="round369666 tl"></b><b class="round369666 tr"></b><b class="round369666 bl"></b><b class="round369666 br"></b></a><br />');
	c.push('</div>');
	c.push('</div>');
	c.push('</center>');

	InfoBox.draw(c.join(''),'Give A Present');
}


function restockItems(response) {
	var names = new Array();
	var name;
	var type;

	try {   
		names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;
		if (response.getElementsByTagName('previousOwner')[0].firstChild) {
			names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
			names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
		}
		names['ownerId'] = response.getElementsByTagName('ownerId')[0].firstChild.nodeValue;
		name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
		type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
	}catch(e){alert('we have a pocket problem! '+e.message);}

	var target = document.getElementById('yourItemsHolder');
	if (target.innerHTML.indexOf('no more items') != -1 || target.innerHTML.indexOf('carrying') != -1) {
		target.innerHTML='';
	}
	var a = document.createElement('a');
	a.id = names['id'];
	a.href = '#';

	var im = document.createElement('img');
	im.src='/img/items/'+type+'/'+name+'.gif';
	im.title = 'Given by '+names['previousOwner'];
	im.width='42';
	im.height='42';

	a.appendChild(im);

	var remover = document.getElementById('profileItemsHolder');
	var oldSpot = document.getElementById(names['id']);
	var oldText = oldSpot.nextSibling;
	remover.removeChild(oldSpot);
	remover.removeChild(oldText);
	target.appendChild(a);
	target.appendChild(document.createTextNode('  '));
	if (remover.innerHTML.indexOf('Given by') == -1) {
		remover.appendChild(document.createTextNode('You have no more items to pocket!'));
	}

	document.getElementById(names['id']).onclick =  getGiveItem_dynamic;

	return false;
}

function tradeItem(response) {
	var names = new Array();
	var name;
	var type;

	try {
		names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;
		names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
		names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
		name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
		type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
	}catch(e){alert('we have a drawer problem! '+e.message);}

	var target = document.getElementById('profileItemsHolder');
	if (target.innerHTML.indexOf('no more') != -1 || target.innerHTML.indexOf('presents') != -1) {
		target.innerHTML = '';
	}
	var a = document.createElement('a');
	a.id = names['id'];
	a.href = '#';

	var im = document.createElement('img');
	im.src='/img/items/'+type+'/'+name+'.gif';
	im.title = 'Given by '+names['previousOwner'];
	im.width='42';
	im.height='42';

	a.appendChild(im);

	var remover = document.getElementById('yourItemsHolder');
	var oldSpot = document.getElementById(names['id']);
	var oldText = oldSpot.nextSibling;
	remover.removeChild(oldSpot);
	remover.removeChild(oldText);
	target.appendChild(a);
	target.appendChild(document.createTextNode('  '));
	if (remover.innerHTML.indexOf('Given by') == -1 && remover.innerHTML.indexOf('Click to') == -1) {
		remover.appendChild(document.createTextNode('You have no more items to give!'));
	}

	document.getElementById(names['id']).onclick = getItemInfo_dynamic;

	return false;
}

var images = new Array();
function preloadPhoto(id) {
	var img = new Image();
	img.src = 'http://img.consumating.com/photos/'+thisprofileid+'/large/'+id+'.jpg';
	images[id] = img;
	
	var img = new Image();
	img.src = 'http://img.consumating.com/photos/'+thisprofileid+'/100/'+id+'.jpg';
	images[id+',100'] = img;
	return false;
}

function swapPhoto(ele) {
	var newId = ele.id.substr(5);
	var main = document.getElementById('mainphoto').getElementsByTagName('img')[0];
	var lower = document.getElementById('photo'+newId);
	var oldId = main.id.substr(5);

	main.src = images[newId] || 'http://img.consumating.com/photos/'+thisprofileid+'/large/'+newId+'.jpg';
	main.id = 'photo'+newId;


	lower.id = 'photo'+oldId;
	lower.src = images[oldId+',100'] || 'http://img.consumating.com/photos/'+thisprofileid+'/100/'+oldId+'.jpg';

	return false;
}

function submitTopicResponse() {
	var topicId = document.getElementById('topicId').value;
	var responsebox = document.getElementById('topicResponse');
	var handle = currentuserhandle;
	var linkhandle = currentuserlinkhandle;

	if (!responsebox.value.length) { alert('You need to say something if you want to respond!'); return false; }

	apiRequest('topic.response','a=1&b=2&topicId='+topicId+'&response='+encodeURIComponent(responsebox.value),handleTopicResponse);
	
	var text = responsebox.value;
	var nolimit = 0;
		
	var target = document.getElementById('responsesArea');

	var buffer = document.createTextNode('');
	var d = document.getElementById('emptyresponse').cloneNode(1);

	var spots = document.all ? new Array(0,1,0) : new Array(1,3,1);
	var notMyTopic = document.getElementById('notMyTopic').value;
	if (notMyTopic > 0) {
		spots[1] = spots[0];
	}

	d.style.display='inline';
	d.id = 'response0000';

	if (notMyTopic == 0) {
		d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]].id='responseimg0000';
		d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]].onclick=function(){deleteTopicResponse(d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]])};
	}

	
	d.childNodes[spots[2]].childNodes[spots[1]].innerHTML='';

	var newresp = document.createElement('p');
	newresp.innerHTML = '<a href="/profiles/'+linkhandle+'">'+handle+'</a> said, ';
	var ss = document.createElement('span');
	ss.id = 'response0000_text';
	if (text && text.length) {
		var parts = text.split('\n');
		for (var i=0;i<parts.length;i++) {
			ss.innerHTML = ss.innerHTML + parts[i];
			ss.appendChild(document.createElement('br'));
		}
	}
	newresp.appendChild(ss);
	d.childNodes[spots[2]].childNodes[spots[1]].appendChild(newresp);
		
	if (!document.all) target.insertBefore(buffer,target.firstChild);
	target.insertBefore(d,target.firstChild);
	if (!document.all) target.insertBefore(buffer,target.firstChild);


	if (nolimit != 1 && (target.childNodes.length == 9 || (document.all && target.childNodes.length > 3) ) ) {
		target.removeChild(target.childNodes[target.childNodes.length-1]);
		if (!document.all) target.removeChild(target.childNodes[target.childNodes.length-1]);
	}

	responsebox.value='';

}

function handleTopicResponse(response,text,nolimit) {
	var responsebox = document.getElementById('topicResponse');
	response = response.responseXML;
	try {
		var responseId = response.getElementsByTagName('responseId')[0].firstChild.nodeValue;
		var handle = response.getElementsByTagName('handle')[0].firstChild.nodeValue;
		var linkhandle = response.getElementsByTagName('linkhandle')[0].firstChild.nodeValue;
	} catch(e){alert('error HTR1: '+e.message)}

	var target = document.getElementById('responsesArea');

	var buffer = document.createTextNode('');
	var d = document.getElementById('emptyresponse').cloneNode(1);

	var spots = document.all ? new Array(0,1,0) : new Array(1,3,1);
	var notMyTopic = document.getElementById('notMyTopic').value;
	if (notMyTopic > 0) {
		spots[1] = spots[0];
	}

	d.style.display='inline';
	d.id = 'response'+responseId;

	if (notMyTopic == 0) {
		d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]].id='responseimg'+responseId;
		d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]].onclick=function(){deleteTopicResponse(d.childNodes[spots[2]].childNodes[spots[0]].childNodes[spots[0]])};
	}

	var a = document.createElement('a');
	a.href='/profiles/'+linkhandle;
	//a.appendChild(document.createTextNode(handle));
	a.innerHTML = handle;
	
	d.childNodes[spots[2]].childNodes[spots[1]].innerHTML='';
	d.childNodes[spots[2]].childNodes[spots[1]].appendChild(a);
	d.childNodes[spots[2]].childNodes[spots[1]].appendChild(document.createTextNode(' said, '));
	var txt = $('response0000_text').cloneNode(true);
	txt.id='';
	d.childNodes[spots[2]].childNodes[spots[1]].appendChild(txt);
	$('response0000').parentNode.removeChild($('response0000'));

//	d.childNodes[spots[1]].innerHTML = '<a href="/profiles/'+linkhandle+'">'+handle+'</a> said: '+(text.length ? text : responsebox.value);
		
	if (!document.all) target.insertBefore(buffer,target.firstChild);
	target.insertBefore(d,target.firstChild);
	if (!document.all) target.insertBefore(buffer,target.firstChild);


	if (nolimit != 1 && (target.childNodes.length == 9 || (document.all && target.childNodes.length > 3) ) ) {
		target.removeChild(target.childNodes[target.childNodes.length-1]);
		if (!document.all) target.removeChild(target.childNodes[target.childNodes.length-1]);
	}

	if (!text) responsebox.value='';
}

function showWholeTopic(topicId) {
	submitRequest('topic.generateList','','topicId='+topicId+'&limit=all');
}
function handleGenerateList(response) {
	try {
		var did = response.getElementsByTagName('deletedId')[0].firstChild.nodeValue;
	}catch(e){}
	try {
		var responses = response.getElementsByTagName('Presponse');

		try {
			var target = document.getElementById('responsesArea');
			target.innerHTML='';

			var target = document.getElementById('responsesArea');

			var buffer = document.createTextNode('');
			for (var i=0;i<5;i++) {
				target.insertBefore(buffer,target.firstChild);
			}
		}catch(e){alert('error HGL1: '+e.message)}

		for (var i=responses.length-1;i>=0;i--) { 
			handleTopicResponse(responses[i],responses[i].getElementsByTagName('response')[0].firstChild.nodeValue,1);
		}
	}catch(e){alert('error HGL2: '+e.message)}
}

function deleteTopicResponse(e) {
	if (!e || !e.id) {
		if (e && e.target) e = e.target;
		else if (e.srcElement) e = e.srcElement;
	}

	var rid = e.id.substring(11);


	new Ajax.Updater('responsesArea','/api',{method:'get',asynchronous:true,parameters:'method=topic.deleteResponse&responseId='+rid});
}

function stopTopic() {
	submitRequest('topic.close','','');

	document.getElementById('topicBox').style.display='none';
	document.getElementById('startnewtopicbox').style.display='block';
	var s = document.getElementById('newtopicspan');
	s.innerHTML = 'Click to start a new topic';
	s.onclick=startTopic;
}

function startTopic() {
	var s = document.getElementById('startnewtopicbox');
	//s.innerHTML='<input class="text" type="text" id="newtopic"/><input type="button" onclick="submitNewTopic();" value="Start Topic"/>';
	//s.onclick=null;

//	var i = document.createElement('input');
//	i.type='text';
//	i.id = 'newtopic';
//	s.appendChild(i);

//	var b = document.createElement('input');
//	b.type='button';
//	b.onclick=submitNewTopic;
//	b.value = 'Start Topic';
//	s.appendChild(b);

	var n = document.getElementById('newtopicentry');
	n.style.display = 'block';
	s.style.display = 'none';
}

function submitNewTopic() {
	var t = document.getElementById('newtopic');
	var c = document.getElementById('profileChannel');

	
	if (!t.value.length) { alert('You need to say something if you want to have a conversation!'); return false; }
	if (c.options[c.selectedIndex].value=='0') { alert('Please select a channel for this conversation'); return false; }
	
	submitRequest('topic.start','','profileChannel=' + c.options[c.selectedIndex].value + '&topic='+encodeURIComponent(t.value));
	t.value = '';
}

function handleNewTopic(response) {
	try {
		document.getElementById('topicBox').style.display='block';
		document.getElementById('startnewtopicbox').style.display='none';
		document.getElementById('newtopicentry').style.display='none';
		document.getElementById('topictitle').innerHTML = response.getElementsByTagName('title')[0].firstChild.nodeValue;
		document.getElementById('topicId').value = response.getElementsByTagName('topicId')[0].firstChild.nodeValue;
		document.getElementById('topicResponses').innerHTML='';
		var l = document.getElementById('topicPermalink');
		var i = l.href.indexOf('id=');
		l.href = l.href.substring(0,i)+'id='+response.getElementsByTagName('topicId')[0].firstChild.nodeValue;
	} catch(e) {}
}

function deleteConversation(id) {
	submitRequest('topic.delete','','topicId='+id);
	return true;
}

function removeTopic(id) {
	var c = new Array();
	c.push("<form method='post'>");
	c.push("<input type='hidden' id='deleteTopicId' name='topicId' value='"+id+"'>");
	c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='deleteConversation("+id+");InfoBox.clear();' class='infoBoxOption'><div class='ibp'>Delete</div></a>");
	c.push("<div class='infoBoxOptionDesc'>Delete this conversation.</div></div><BR clear='all' />");
	c.push("<div class='infoBoxOptionWrapper'><a href='#' onClick='InfoBox.clear();return false;' class='infoBoxOption'><div class='ibp'>Cancel</div></a>");
	c.push("<div class='infoBoxOptionDesc'>Don\'t delete this conversation.</div></div><BR clear='all' />");

	c.push('</form>');
	InfoBox.draw(c.join(''),'Delete Conversation');
}	
function handleTopicDelete(response) {
	try {
		var id = response.getElementsByTagName('id')[0].firstChild.nodeValue;
		var box = document.getElementById('topicbox'+id);
		box.parentNode.removeChild(box);
	} catch(e){alert(e.message)}
}


function photobling(id,type) {
	url = "/weekly/photo/index.pl/bling?en=" + id + "&t=" + type;
	http.open("GET",url,true);
	http.onreadystatechange= handlePhotoBling;
	http.send(null);
	bid = id;

	if (type == "U") {
		obj = document.getElementById('photobling'+bid+"-up");
		obj.src = "/img/photoup-on.gif";
		obj = document.getElementById('photobling'+bid+"-down");
		obj.src = "/img/photodown.gif";

	} else {
		obj = document.getElementById('photobling'+bid+"-down");
		obj.src = "/img/photodown-on.gif";
		obj = document.getElementById('photobling'+bid+"-up");
		obj.src = "/img/photoup.gif";
	}



	return false;

}

function handlePhotoBling() {
	if (http.readyState == 4) {
		resultsT = http.responseText;
		var results = new Array();
		results = resultsT.split(';');

		try {
			var up = document.getElementById(bid+'Up');
			var dn = document.getElementById(bid+'Dn');
			if (results[1].split('-')[0] == 'U') {
				up.innerHTML = results[1].split('-')[1];
				dn.innerHTML = results[2].split('-')[1];
			} else {
				up.innerHTML = results[2].split('-')[1];
				dn.innerHTML = results[1].split('-')[1];
			}
		} catch(e) {}

		bid ='';
	}
}

function bbhelp() {
	var txt = 'To prevent improper html code from making the site harder to use, Consumating uses bbcode to format messages.  It\'s easier than you think!  Here\'s a quick guide.  <br/><br/> link to a profile: [[The Unabageler]] == <a href="/profiles/The_Unabageler">The Unabageler</a><br/> email address: [email]bobdole@bobdole.com[/email] == <a href="mailto:bobdole@bobdole.com">bobdole@bobdole.com</a><br/> web link: [url="http://consumating.com"]Consumating![/url] == <a href="http://consumating.com">Consumating!</a><br/> Underline:  [u]blah blah[/u] == <u>blah blah</u><br/> Italics: [i]blah blah[/i] == <i>blah blah</i><br/> Bold: [b]blah blah[/b] == <b>blah blah</b><br/> <br/> <br/>Now was that so bad?';
	var opt = new Array();
	opt[0] = new Array('MozOpacity',1);
	InfoBox.draw(txt,'So, you want to format your message?',opt);
}

function changeTagline() {
	document.getElementById('taglinelink').onclick=function(){return false;};
	var tl = document.getElementById('tagline').innerHTML;
	var c = new Array();
	c.push('<input type="text" name="newtagline" id="newtagline" value="'+tl+'"/>');
	c.push('<input type="button" class="hundred" value="Update" onclick="saveTagline();"/>');
	document.getElementById('tagline').innerHTML = c.join('<br/>');
}
function saveTagline() {
	var tl = document.getElementById('newtagline').value;
	document.getElementById('tagline').innerHTML = tl;
	submitRequest('user.saveTagline','','tagline='+tl);
	document.getElementById('taglinelink').onclick=changeTagline;
}

function handleProfileResponse() { }

function qowNSFW(rid,userId) {
	apiRequest('admin.qow_nsfw','rid='+rid+'&userId='+userId,null);
	return true;
}

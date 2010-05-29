function getItemInfo(userId,itemId) {
	submitRequest('item.getInfo','','userId='+userId+'&itemId='+itemId);
	return false;
}

function storeItem(itemId) {
	apiRequest('item.store','itemId='+itemId,handle_storeItem);
}
function handle_storeItem(r) {
	if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') != 'ok') {
		$('itemInfo').innerHTML = 'Something went wrong!  Refresh the page and try again or contact the Feedback Zombie.';
		return false;
	}
	$('itemInfo').innerHTML = 'Stored!';
	try {
		var id = r.responseXML.getElementsByTagName('dat')[0].firstChild.nodeValue;
		document.getElementById('slotimg'+id).parentNode.removeChild(document.getElementById('slotimg'+id));
	} catch(e) {alert(e.message)}
		
}

function pocketItem(itemId) {
	apiRequest('item.pocket','itemId='+itemId,handle_pocketItem);
}
function handle_pocketItem(r) {
	if (r.responseXML.getElementsByTagName('rsp')[0].getAttribute('stat') != 'ok') {
		$('itemInfo').innerHTML = 'Something went wrong!  Refresh the page and try again or contact the Feedback Zombie.';
		return false;
	}
	$('itemInfo').innerHTML = 'Pocketed!';
	try {
		var id = r.responseXML.getElementsByTagName('dat')[0].firstChild.nodeValue;
		document.getElementById('slotimg'+id).parentNode.removeChild(document.getElementById('slotimg'+id));
	} catch(e) {alert(e.message)}
}


function showItemInfo(response) {
	var names = new Array();
	var name;
	var type;
	try {
		if (response.getElementsByTagName('previousOwner')[0] && response.getElementsByTagName('previousOwner')[0].firstChild) {
			names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
			names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
		}
		if (response.getElementsByTagName('owner')[0] && response.getElementsByTagName('owner')[0].firstChild) {
			names['owner'] = response.getElementsByTagName('owner')[0].firstChild.nodeValue;
			names['ownerId'] = response.getElementsByTagName('ownerId')[0].firstChild.nodeValue;
			names['linkowner'] = response.getElementsByTagName('linkowner')[0].firstChild.nodeValue;
		}
		names['creator'] = response.getElementsByTagName('creator')[0].firstChild.nodeValue;
		names['linkcreator'] = response.getElementsByTagName('linkcreator')[0].firstChild.nodeValue;
		names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;

		name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
		try { description = response.getElementsByTagName('description')[0].firstChild.nodeValue;}catch(e){ description = ''; }
		type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
		enabled = response.getElementsByTagName('enabled')[0].firstChild.nodeValue;
		try { behavior = response.getElementsByTagName('behavior')[0].firstChild.nodeValue; }catch(e){ behavior = null; }
		try { behaviorcolor = response.getElementsByTagName('behaviorcolor')[0].firstChild.nodeValue; }catch(e){ behaviorcolor = null; }
		try { points = response.getElementsByTagName('points')[0].firstChild.nodeValue; }catch(e){ points = null; }
	}catch(e){}

	var c = new Array();
	var r = new Array();

	try {
		if (names['owner'] == currentuserhandle) {
			r.push('<div style=" margin-right:-15px; padding:5px; ">');
			var d = new Array();
			$('trashbutton').style.display='inline';
			$('trashbutton').onclick=function(){tossItem(names['id']); return false;};
			$('pocketbutton').style.display='inline';
			$('pocketbutton').onclick = function(e){pocketItem(names['id']);return false;};

			if (names['creator'] == names['owner']) {
				$('editbutton').style.display='inline';
				$('editbutton').href='/toys/create.csm?itemId='+names['id'];
			} else {
				$('editbutton').style.display='none';
				$('editbutton').href='';
			}
			if (type == 'user') {
				$('clonebutton').style.display='inline';
				$('clonebutton').onclick = function(){cloneItem(names['id'])};
			} else {
				$('clonebutton').style.display='none';
				$('clonebutton').onclick = '';
			}
			r.push(d.join('&nbsp;|&nbsp;'));
		} else {
			r.push('<div style="margin-right: -15px; padding: 5px;">');
			if (currentuserid && currentuserid != names['ownerId']) {// && points > 0) {
				$('purchasebutton').style.display='inline';
				$('purchasebutton').onclick = function(){purchaseItem(names['id'],points,names['ownerId'])};
				//r.push('<a style="margin:5px;" href="#" onclick="purchaseItem('+names['id']+','+points+','+names['ownerId']+');return false;">Purchase</a>');
			}
		}
		//r.push('<a style="margin:5px;" href="#" onClick="$(\'inspectordropper\').innerHTML=\'\';document.getElementById(\'itemInfo\').innerHTML=\'Click an item to view more information.\';" >Thanks!</a>');
		r.push('</div>');
	} catch(e){}

	try {
		var dt = new Date();

		c.push('This <span class="blue">' + name + '</span>');
		if (currentuserhandle == names['creator'] && names['creator'] == names['owner']) {
			c.push(' was made by you!');
		} else if (names['creator'] == names['owner']) {
			c.push(' was made by '+names['owner']);
		} else if (names['previousOwner']) {
			c.push(' was given by <a href="/profiles/'+names['linkpreviousOwner']+'">'+names['previousOwner']+'</a>.');
		} else {
			c.push(' was given by <span class="blue">a secret admirer</span>!');
		}
		c.push('<br/>'+description);

		if (points > 0) {
			c.push('<br/>It can be sold for '+points+' point'+(points == 1 ? '' : 's')+'.');
		}
	}catch(e){}
	if (names['creator'] != names['owner']) {
		if (names['creator'] == currentuserhandle) {
			c.push('It was created by you. <br/>');
		} else {
			c.push('It was created by <a href="/profiles/'+names['linkcreator']+'">'+names['creator']+'</a>.<br/>');
		}
	}

	
	c.push(r.join(''));
	c.push('</center>');
	document.getElementById('itemInfo').innerHTML = c.join('');
	if ($('itemInfo').style.display == 'none') {
		Effect.BlindDown('itemInfo');
	}
}

function handleEnableItem(response) {
	var items = response.getElementsByTagName('item');
	for (var i=0;i<items.length;i++) {
		var item = items[i];
		var id = item.getAttribute('id');
		var enabled = item.getAttribute('enabled');

		if (enabled == 1) {
			var behavior = item.firstChild.nodeValue;
			setBehavior(behavior);
			document.getElementById('item'+id).style.borderColor = 'red';
		} else {
			document.getElementById('item'+id).style.borderColor = 'blue';
		}
	}
	document.getElementById('itemInfo').innerHTML = 'Click an item to view more information.';
}

function tossItem(itemId) {
	if (confirm("Are you sure you want to toss this?  It cannot be retrieved!")) {
		submitRequest('item.toss','','itemId='+itemId);
	}
}
function handleTossItem(response) {
	try {
		var itemId = response.getElementsByTagName('itemId')[0].firstChild.nodeValue;
		var d = document.getElementById('item'+itemId);
		d.parentNode.removeChild(d);
		document.getElementById('itemInfo').innerHTML = 'Click an item to view more information.';
	}catch(e){alert('error Ti1: '+e.message)}

	$('inspectordropper').innerHTML = '';
	$('editbutton').style.display='none';
	$('clonebutton').style.display='none';
	$('trashbutton').style.display='none';

	blankTileCheck();
}

function blankTileCheck() {
	// do we have enough blanks? if not, let's make enough.
	try {
		var items = document.getElementsByExactClassName('tile');
		var blanks = document.getElementsByExactClassName('tile blank');
		var lenTest = (items.length % 6);
		if (lenTest == 0) {
			// kill extra row
			for (var i=0;i<6;i++) {
				blanks[i].parentNode.removeChild(blanks[i]);
			}
		} else if (lenTest + blanks.length != 6) {
			for (var i=lenTest+blanks.length;i<6;i++) {
				var nb = getBlankTile();
				nb.id='newblank';
				$('inventory').appendChild(nb);
				$('newblank').className = 'tile blank';
				$('newblank').id = '';
			}
		}
	} catch(e) {}
}
function getBlankTile() {
	var newblank = document.getElementById('blank').cloneNode(true);
	newblank.id='';
	newblank.style.display='block';
	newblank.style.className = 'tile blank';
	return newblank;
}

function purchaseItem(itemId,points,ownerId) {
	//if (confirm("This will cost you "+points+" points.  Are you sure you want to purchase?")) {
		submitRequest('item.purchase','','itemId='+itemId+'&points='+points+'&ownerId='+ownerId);
	//}
	return false;
}
function handlePurchaseItem(response) {
	try { var id = response.getElementsByTagName('itemId')[0].firstChild.nodeValue; } catch(e) { alert(e.message) }
	if (id) {
		var d = document.getElementById('itemInfo');
		d.innerHTML = 'Purchase complete. Thank you for your patronage!';
	}
}
		

function cloneItem(itemId) {
	//if (confirm("This will cost you 3 points.  Do you want to continue?")) {
		var d = document.getElementById('itemInfo');
		d.innerHTML = 'working...';
		submitRequest('item.clone','','itemId='+itemId);
	//}
	return false;
}
function handleCloneItem(response) {

	var id = response.getElementsByTagName('id')[0].firstChild.nodeValue;
	var oldid = response.getElementsByTagName('oldid')[0].firstChild.nodeValue;

	try {
		// clone image
		var im = document.getElementById('itemimg'+oldid);
		var newim = im.cloneNode(true);
		newim.id='itemimg'+id;
		newim.src = '/img/items/user/'+id+'.gif';

		// clone link
		var lk = document.getElementById('itemlink'+oldid);
		var newlk = lk.cloneNode(false);
		newlk.id='itemlink'+id;
		newlk.innerHTML='';
		newlk.appendChild(newim);

		$('itemInfo').innerHTML = 'Cloning complete!';
		
		// clone div
		var dv = document.getElementById('item'+oldid);
		var newdv = dv.cloneNode(false);
		newdv.id='item'+id;
		newdv.appendChild(newlk);

		document.getElementById('inventory').insertBefore(newdv,dv);
	}catch(e){alert('C1a: '+e.message)}

	try {
		var ni = document.createElement('input');
		ni.type='hidden';
		ni.id='owner'+id;
		ni.value = document.getElementById('owner'+oldid).value;
		document.getElementById('inventoryForm').appendChild(ni);
	}catch(e){alert('C2: '+e.message)}

	try {
		new Draggable("item"+id,{revert:true});
	}catch(e){alert('C3: '+e.message)}


	// get rid of the last empty tile
	var blanks = document.getElementsByExactClassName('tile blank');
	if (blanks.length) {
		blanks[0].parentNode.removeChild(blanks[0]);
	}

	blankTileCheck();
}

function giveawayItem() {
	new Ajax.Request('/api',{
		method:'get',
		parameters:'method=item.give&handle='+$('giveawayname').value+'&itemId='+$('giveawayItemId').value,
		onComplete:giveawayComplete
	});
}
function giveawayComplete(resp) {
	try {
		var response = resp.responseXML;
		var stat = response.getElementsByTagName('rsp')[0];

		$('giveawayItemId').value='';
		$('giveawayDrop').innerHTML='';
		if (stat.getAttribute('stat') == 'ok') {
			var id = response.getElementsByTagName('id')[0].firstChild.nodeValue;
			document.getElementById('item'+id).parentNode.removeChild(document.getElementById('item'+id));
			blankTileCheck();
			alert('Giveaway complete!');
			$('giveawayItemId').value = '';
			$('giveawayname').value='';
			$('giveawayInfo').style.display='none';
		} else {
			alert('Oh no!  Giveaway failed!');
		}
	} catch(e) { alert('error gc1: ' + e.message) }
}

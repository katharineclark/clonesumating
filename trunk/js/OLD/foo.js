
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
		names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
		names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
		names['creator'] = response.getElementsByTagName('creator')[0].firstChild.nodeValue;
		names['linkcreator'] = response.getElementsByTagName('linkcreator')[0].firstChild.nodeValue;
		names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;

		name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
		type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
	}catch(e){}
	InfoBox.draw('some info','Details');
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

	InfoBox.draw('giving instructions','Give A Present');
}


function restockItems(response) {
	var names = new Array();
	var name;
	var type;

	try {   
		names['id'] = response.getElementsByTagName('id')[0].firstChild.nodeValue;
		names['previousOwner'] = response.getElementsByTagName('previousOwner')[0].firstChild.nodeValue;
		names['ownerId'] = response.getElementsByTagName('ownerId')[0].firstChild.nodeValue;
		names['linkpreviousOwner'] = response.getElementsByTagName('linkpreviousOwner')[0].firstChild.nodeValue;
		name = response.getElementsByTagName('name')[0].firstChild.nodeValue;
		type = response.getElementsByTagName('type')[0].firstChild.nodeValue;
	}catch(e){alert('we have a problem! '+e.message);}

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
	target.innerHTML = target.innerHTML + '&nbsp;&nbsp;';
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
	}catch(e){alert('we have a problem! '+e.message);}

	var target = document.getElementById('profileItemsHolder');
	if (target.innerHTML.indexOf('no more') != -1 || target.innerHTML.indexOf('valentines') != -1) {
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
	target.innerHTML = target.innerHTML + '&nbsp;&nbsp;';
	if (remover.innerHTML.indexOf('Given by') == -1 && remover.innerHTML.indexOf('Click to') == -1) {
		remover.appendChild(document.createTextNode('You have no more items to give!'));
	}

	document.getElementById(names['id']).onclick = getItemInfo_dynamic;

	return false;
}


function thumb(direction,type,id) {

// immediately update the user interface
	if (direction == "U") {
		document.getElementById('thumbsup_'+type+'_'+id).src = 'http://img.consumating.com/img/dashboard/up-small-on.gif';
		document.getElementById('thumbsdown_'+type+'_'+id).src = 'http://img.consumating.com/img/dashboard/down-small.gif';
	} else {
		document.getElementById('thumbsup_'+type+'_'+id).src = 'http://img.consumating.com/img/dashboard/up-small.gif';
		document.getElementById('thumbsdown_'+type+'_'+id).src = 'http://img.consumating.com/img/dashboard/down-small-on.gif';
	}

// send ajax call to API
	if (type == "question") { 
		apiRequest('user.qowbling','responseId='+id+'&direction='+direction,handleBling);
	} else {
		apiRequest('user.photobling','userId='+id+'&direction='+direction,handleBling);
	}


	return false;
}

function handleBling(r) {
	var resultsT = r.responseText;
}


function hotlist(userId) {
	var ele = document.getElementById('hotlist'+userId);
	if (ele.innerHTML == '+ Keep Forever') {
		try { document.getElementById('fade'+userId).style.display='none' } catch(e) {}
		ele.innerHTML = 'x Remove';
		apiRequest('user.addToHotList','userId='+userId);
	} else {
		try { document.getElementById('fade'+userId).style.display='block' } catch(e) {}
		ele.innerHTML = '+ Keep Forever';
		apiRequest('user.removeFromHotList','userId='+userId);
	}
}

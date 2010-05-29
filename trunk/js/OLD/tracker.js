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

function checkMessages(userId) {
	return submitRequest('user.checkMessages','','userId='+userId);
}
function updateMessages(response) {
	try {
		var count = response.getElementsByTagName('newmessages')[0].firstChild.nodeValue;
		if (count == 0) { return; }
		var sp = document.getElementById('newmessages');
		sp.innerHTML = count + ' new msgs';
	} catch(e) {}
	return false;
}

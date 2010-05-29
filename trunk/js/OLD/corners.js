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

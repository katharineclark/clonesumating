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

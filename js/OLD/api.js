function consumatingAPI() {
	var userhash = null;
	var xmlhttp = null;
	var callback = null;
	var data = null;
	var command = null;
	var extra = null;
	var mode = null;
	var retries = 0;

	this.getHTTPObject = function() {
		try {
			this.xmlhttp = new ActiveXObject("Msxml2.XMLHTTP");
		} catch(e) {
			try {
				this.xmlhttp = new ActiveXObject("Microsoft.XMLHTTP");
			} catch(e) {
				try {
					this.xmlhttp = new XMLHttpRequest();
				} catch(e) {
					alert("Your browser does not support AJAX protocols required to use this site!");
				}
			}
		}
	}

	this.request = function(command,params,callback) {
		this.callback = callback;
		this.data = 'method='+command;
		this.command = command;
		if (this.retries == 0) {
			this.retry = new Array();
		}

		if (typeof(command) == 'string') {
			// new request
			var pairs = params.split('&');
			for (var i=0;i<pairs.length;i++) {
				var ele = pairs[i].split('=');
				data = data + '&' + ele[0] + '=' + escape(ele[1]);
				cnt++;
			}
			var ts = new Date();
			if (cnt > 3) {
				this.mode = 'POST';
				this.extra = '?sometime='+ts.getTime();
			} else {
				this.mode = 'GET';
				this.extra = '?sometime='+ts.getTime()+'&'+data;
				this.data = null;
			}
		}
		
		try {
			this.xmlhttp.open(this.mode,'/api'+this.extra,true);
			this.xmlhttp.onreadystatechange = this.handleResponse;
			this.xmlhttp.setRequestHeader('Content-Type','application/x-www-form-urlencoded');
			this.xmlhttp.send(data);
		} catch(e) {
			alert('Unable to send XmlHTTP request! '+e.message);
		}
		return false;
	}

	this.handleResponse = function() {
		var response;
		try {
			if (this.xmlhttp && this.xmlhttp.readyState && this.xmlhttp.readyState == 4) {
				if (this.xmlhttp.status && this.xmlhttp.status == 404) {
					alert('404: api interface not found.');
				} else if (this.xmlhttp.status && this.xmlhttp.status == 200) {
					this.results = new Array(this.xmlhttp.responseText,this.xmlhttp.responseXML);
					this.xmlhttp = this.getHTTPObject();
					if (results[0] && results[1]) {
						this.retries = 0;
						try {
							var status = results.getElementsByTagName('rsp')[0].getAttribute('stat');
							if (status == "ok") {
								this.callback(this.results);
							} else if (status == "fail") {
								var error = results.getElementsByTagName('error')[0].getAttribute('msg');
								this.callback(error);
							} else {
								alert('Unknown command response: Af937');
							}
						} catch(e) {
							alert('error api XHR1: '+e.message)
						}
					} else {
						retries++;	
						setTimeout('submitRequest()',1500);
					}
				}
			}
		} catch(e) {
		}
	}
	

	this.getHTTPObject();

	return this;
}

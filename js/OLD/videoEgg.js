function videoEgg() {
	var VE_api = VE_getPlayerAPI("1.2");

	this.initPlayer = function() {
		document.write('<script language="javascript" src="http://update.videoegg.com/js/Player.js"></script>');
	}

	this.drawMovie = function(path,small) {
		var h = 330;
		var w = 350;
		if (small) {
			h = 110;
			w = 117;
		}
		try {
			document.write('<div class="video">');
			VE_api.embedPlayer(path, w, h, false, "", "", false, "", "");
			document.write('</div>');
		}catch(e){alert('draw error ('+path+'): '+e.message)}
	}

	this.drawThumb = function(path,width) {
		var thumbURL = VE_api.getThumbnailURL(path);
		if (!width) width = 100;
		document.write("<img class='videoThumb' style='width:"+width+";' src='"+thumbURL+"'/>");
	}
	this.getThumb = function(path,width) {
		try {
			var thumbURL = VE_api.getThumbnailURL(path);
			if (!width) width = 100;
			return "<img class='videoThumb' style='width:"+width+";' src='"+thumbURL+"'/>";
		} catch (e) { alert('getThumb error: '+e.message) }
	}

	this.saveVideo = function(path,duration,src) {
		try {
			var name,desc;
			try {
				name = $('videoName').value;
				desc = $('videoDesc').value;
			}catch(e){
				//alert('no name or desc: '+e.message);
				name = '';
				desc = '';
			}
			apiRequest("user.saveVideo","path="+path+"&duration="+duration+"&src="+src+"&name="+name+"&desc="+desc, function(r){videoEgg.videoSaved(r,path)});
		}catch(e){
			alert('error saving video: \n'+path+', '+duration+', '+src+'\n'+e.message)
		}
	}
	this.videoSaved = function(r,path) {
		r = r.responseXML;
		if (r.getElementsByTagName('id').length > 0) {
				// show picked
				var id = r.getElementsByTagName('id')[0].firstChild.nodeValue;
				$('videoId').value = id;
				$('videopublisher').style.display='none';
				$('videopicked').style.display='inline';
				$('videoPickedThumb').innerHTML = this.getThumb(path);
		} else {
			alert('failed to save video!  this is bad.  Talk to feedback zombie.');
		}
	}
}

var videoEgg = new videoEgg;

function VE_saveVideo(path,duration,src) {
	try {
		videoEgg.saveVideo(path,duration,src);
	}catch(e){alert('VE_saveVideo error: '+e.message)};
}

function mediashower() {
	var type = '';
	var id = '';

	this.load = function(i,j) {
		this.type = i;
		this.id = j;
	};

	this.show = function() {
//alert('show1 '+this.id);
		try{
		var c = new Array();
		if (this.type == 'rockyou') {
			c.push('<embed id="slideshowEmbed" src="http://apps.rockyou.com/rockyou.swf?instanceid='+this.id+'"');
			c.push(' quality="high" wmode="transparent" name="flashticker" align="middle" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer"/>');
		} else if (this.type == 'youtube') {
			c.push('<object><param name="movie" value="http://www.youtube.com/v/'+this.id+'"></param>');
			c.push('<embed src="http://www.youtube.com/v/'+this.id+'" type="application/x-shockwave-flash" width="425" height="350"></embed></object>');
		} else if (this.type == 'revver') {
			c.push('<embed src="http://media.revver.com/broadcast/'+this.id+'/video.mov" pluginspage="http://www.apple.com/quicktime/download/" scale="tofit"');
			c.push('kioskmode="False" qtsrc="http://media.revver.com/broadcast/'+this.id+'/video.mov" cache="False" height="272" width="320" controller="True"');
			c.push('type="video/quicktime" autoplay="False"></embed>');
		} else if (this.type == 'ifilm') {
			c.push('<embed allowScriptAccess="never" width="400" src="http://www.ifilm.com/efp" quality="high" bgcolor="000000" name="efp"');
			c.push('align="middle" type="application/x-shockwave-flash" pluginspage="http://www.macromedia.com/go/getflashplayer" flashvars="flvBaseClip='+this.id+'" />');
		} else if (this.type == 'flickr') {
		} else if (this.type == 'rss') {
		} else if (this.type == 'sound') {
//alert('show '+this.id);
			c.push('<embed src="'+this.id+'" autostart="true"loop="flase" hidden="true"><noembed><bgsound src="'+this.id+'" loop= "0"></noembed>');
			c.push('');
		}

		return c.join('');
		}catch(e){alert('Mes1 error: '+e.message)}
	};
}


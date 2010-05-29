function flipButton(ele,dir) {
	var cl = ele.className;
	dir = dir == 'over' ? '_mo' : '';
	for (var i=0;i<ele.childNodes.length;i++) {
		var c = ele.childNodes[i];	
		if (c.className == 'leftbutton') {
			c.style.backgroundImage = "url('http://img.consumating.com/img/buttons/"+cl+"_left"+dir+".gif')";
		} else if (c.className == 'midbutton') {
			c.style.backgroundImage = "url('http://img.consumating.com/img/buttons/"+cl+"_middle"+dir+".gif')";
		} else if (c.className == 'rightbutton') {
			c.style.backgroundImage = "url('http://img.consumating.com/img/buttons/"+cl+"_right"+dir+".gif')";
		}
	}
}

function _makeButton(color,text,href,attr,innerAttr) {
	var c = new Array();
	try {
		c.push('<div class="button"><a class="'+color+'_btn" '+attr+' href="'+href+'" onmouseover="flipButton(this,\'over\');" onmouseout="flipButton(this,\'out\');">');
		c.push('<div class="leftbutton">&nbsp;</div><div class="midbutton"><div '+innerAttr+'>'+text+'</div></div><div class="rightbutton">&nbsp;</div></a></div>');
	} catch(e) { alert('error MBj1: '+e.message) }
	return c.join('');
}
function makeButton(color,text,href,attr,innerAttr) {
	try {
		document.write(_makeButton(color,text,href,attr,innerAttr));
	} catch(e) { alert('error MB0: '+e.message) }
}

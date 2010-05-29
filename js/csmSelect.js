function csmSelect(iname,ioptions,ivalues,dval,trigger) {

	var options = new Array;
	var values = new Array;	
	var inputname;
	var height=40;
	var width=170;
	var cval;
	var triggerFunction;
	

	this.open = function() {

	// get the location of the current object
		var current = document.getElementById(inputname+'current');
		var select = document.getElementById(inputname+'select')

		var y = current.offsetTop + current.offsetParent.offsetTop;
		var x = current.offsetLeft + current.offsetParent.offsetLeft;

		select.style.position = 'absolute';
		//var p = current.offsetParent;
		select.style.left = x + "px";
		select.style.top = (y - (height * (cval)) - options.length) + "px";


		//current.style.display='none';
		select.style.display='block';		

		return true;
	}

	this.close = function() {

		//document.getElementById(inputname+'current').style.display='block';
		document.getElementById(inputname+'select').style.display='none';

	}

	this.click = function(i) {
		if (!document.all)
			i = i.substring(inputname.length);

		cval = i;
		document.getElementById(inputname).value = values[i];

		if (!document.all)
			document.getElementById(inputname + 'current').innerHTML = options[i];

		if (triggerFunction != '') {
			eval(triggerFunction);
		}

		if (!document.all) 
			this.close();
	}

	this.hover = function(i) {
		i = i.substring(inputname.length);
		document.getElementById(inputname + i).className='csmOption_hover';
	}
	this.unhover = function(i) {
		i = i.substring(inputname.length);
		document.getElementById(inputname + i).className='csmOption';
	}



	this.place = function() {
		var def;
		if (document.all) {
			// do a normal selector for these folk
			document.write('<select id="'+inputname+'select">');
			for (i=0;i<options.length;i++) {
				if (values[i] == dval) {
					def = i;
				}
				if (options[i].indexOf('img src') > -1) {
					var idx = options[i].indexOf('.gif');
					options[i] = options[i].substring(0,idx);
					idx = options[i].lastIndexOf('_');
					options[i] = options[i].substring(idx+1);
				}
				document.write('<option value="'+i+'">'+options[i]+'</option>\n');
			}
			document.write('</select>');

			document.getElementById(inputname+'select').onchange=function(){eval(inputname+'.click('+this.options[this.selectedIndex].value+');');};
			document.getElementById(inputname+'select').selectedIndex = def;

			return true;
		}
		document.write('<div class="csmSelect" id="' + inputname + 'select" style="z-index:9999;">');
		for (i=0; i < options.length; i++) {
			if (values[i] == dval) {
				def = i;
			}
			document.write('<div style="z-index:9999;" class="csmOption" id="' + inputname + i + '" onClick="' + inputname + '.click(' +i + ');" onMouseOver="' + inputname+'.hover('+i+');" onMouseOut="' + inputname+'.unhover('+i+');" >' + options[i] + '</div>');
			document.getElementById(inputname+i).onclick=function(){eval(inputname+'.click(this.id);  ');};
			document.getElementById(inputname+i).onmouseover=function(){eval(inputname+'.hover(this.id);  ');};
			document.getElementById(inputname+i).onmouseout =function(){eval(inputname+'.unhover(this.id);');};
		}
		document.write('</div>');

		if (def == "") {
			def = 0;
		}

		cval = def;
		document.getElementById(inputname+'select').style.display='none';
		document.getElementById(inputname+'select').style.zIndex=99999;

		document.write('<div style="z-index:9999;" class="csmCurrent" id="' + inputname + 'current">' + options[def] + '</div>');
		document.getElementById(inputname+'current').onclick=function(){eval(inputname+'.open();');};
		
		document.getElementById(inputname).value = values[def];
	}
	

	for (i =0; i < ioptions.length; i++) {

                options[i] = ioptions[i];
                values[i] = ivalues[i];

	}

	inputname = iname;
	triggerFunction = trigger;

	return true;
}


var theDoc = document;
function parseDate(string,gettime) {
	var date = string.substr(0,10);
	var time = string.substr(11,8);

	if (gettime) {
		return Array(date,time);
	} else {
		return date;
	}
}
function parseTime(string,getseconds) {
	if (getseconds) {
		return string.substr(0,8);
	} else {
		return string.substr(0,5);
	}
}

function timeEntry(name,location,value) {
	var time = new Array();
	var ap=0;
	if (value && value.length) {
		time = value.split(':');
		if (time[0] > 12) { time[0] = time[0] - 12; ap = 1; }
	} else {
		time = new Array();
	}
	if (theDoc.getElementById(name+'_hour')) {
		var e = theDoc.getElementById(name+'_hour');
		for (var i=1;i<=12;i++) {
			if (i < 10) { i = '0' + i; }
			if (time[0] == i) {
				e.options[i-1].selected = true;
			}
		}
	} else {
		var e = theDoc.createElement('select');
		e.name='hour';
		e.id=name+'_hour';
		var sel = time[0] == 0 ? true : false; 
		e.options[e.options.length] = new Option(12,12,sel,sel);
		for (var i=1;i<=11;i++) {
			if (i < 10) { i = '0' + i; }
			var sel = time[0] == i ? true : false;
			e.options[e.options.length] = new Option(i,i,sel,sel);
		}
		theDoc.getElementById(location).appendChild(e);

	}
	if (theDoc.getElementById(name+'_minute')) {
		var e = theDoc.getElementById(name+'_minute');
		for (var i=0;i<60;i++) {
			if (i < 10) { i = '0' + i; }
			if (time[1] == i) {
				e.options[i].selected = true;
			}
		}
	} else {
		var e = theDoc.createElement('select');
		e.name='minute';
		e.id=name+'_minute';
		for (var i=0;i<60;i = (i + 15)*1 ) {
			if (i < 10) { i = '0' + i; }
			var sel = time[1] == i ? true : false;
			e.options[e.options.length] = new Option(i,i,sel,sel);
		}
		theDoc.getElementById(location).appendChild(e);
	}
	if (theDoc.getElementById(name+'_ap')) {
		theDoc.getElementById(name+'_ap').options[ap].selected = true;
	} else {
		e = theDoc.createElement('select');
		e.name='ap';
		e.id=name+'_ap';
		e.options[e.options.length] = new Option('AM',0,false,false);
		e.options[e.options.length] = new Option('PM',1,false,false);
		if (ap) { e.options[1].selected = true; }
		theDoc.getElementById(location).appendChild(e);
	}
}
function getTimeEntry(name) {
	var hour = theDoc.getElementById(name+'_hour').options[theDoc.getElementById(name+'_hour').selectedIndex].value;
	var minute = theDoc.getElementById(name+'_minute').options[theDoc.getElementById(name+'_minute').selectedIndex].value;
	var ap = theDoc.getElementById(name+'_ap').selectedIndex;
	if (hour != 12 && ap > 0) {
		hour = hour - (-12);
	} else if (hour == 12 && ap == 0) {
		hour = '00';
	}
	
	return hour+':'+minute;
}


function dateEntry(name,location,value,startY,endY) {
	var date = new Array();
	if (!startY) startY = 2006;
	if (!endY) endY = 2015;

	if (value && value.length) {
		value = value.substr(0,10);
		date = value.split('-');
	} else {
		date = new Array();
	}

	if (theDoc.getElementById(name+'_month')) {
		var e=theDoc.getElementById(name+'_month');
		for (var i=1;i<=12;i++) {
			if (i < 10) { i = '0' + i; }
			if (date[1] == i) {
				e.options[i-1].selected = true;
			}
		}
	} else {
		var e = theDoc.createElement('select');
		e.name='month';
		e.id=name+'_month';
		for (var i=1;i<=12;i++) {
			if (i < 10) { i = '0' + i; }
			var sel = date[1] == i ? true : false;
			e.options[e.options.length] = new Option(i,i,sel,sel);
		}
		theDoc.getElementById(location).appendChild(e);
	}

	if (theDoc.getElementById(name+'_day')) {
		var e=theDoc.getElementById(name+'_day');
		for (var i=1;i<=31;i++) {
			if (i < 10) { i = '0' + i; }
			if (date[2] == i) {
				e.options[i-1].selected = true;
			}
		}
	} else {
		var e = theDoc.createElement('select');
		e.name='day';
		e.id=name+'_day';
		for (var i=1;i<=31;i++) {
			if (i < 10) { i = '0' + i; }
			var sel = date[2] == i ? true : false;
			e.options[e.options.length] = new Option(i,i,sel,sel);
		}
		theDoc.getElementById(location).appendChild(e);
	}

	if (theDoc.getElementById(name+'_year')) {
		var e=theDoc.getElementById(name+'_year');
		for (var i=0;i<e.options.length;i++) {
			if (date[0] == e.options[i].value) {
				e.options[i].selected = true;
			}
		}
	} else {
		var e = theDoc.createElement('select');
		e.name='year';
		e.id=name+'_year';
		for (var i=startY;i<=endY;i++) {
			var sel = date[0] == i ? true : false;
			e.options[e.options.length] = new Option(i,i,sel,sel);
		}
		theDoc.getElementById(location).appendChild(e);
	}
}
function getDateEntry(name) {
	var month = theDoc.getElementById(name+'_month').options[theDoc.getElementById(name+'_month').selectedIndex].value;
	var day = theDoc.getElementById(name+'_day').options[theDoc.getElementById(name+'_day').selectedIndex].value;
	var year = theDoc.getElementById(name+'_year').options[theDoc.getElementById(name+'_year').selectedIndex].value;

	return year+'-'+month+'-'+day;
}


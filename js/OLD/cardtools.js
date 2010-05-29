var PeopleCart = new Peoplecart();
function assignMouseOver() {
	var divs = new Array;
	divs = document.getElementsByTagName('div');

	var dt = new Date();
	for (i = 0; i < divs.length; i++) {
		if (divs[i].className.substring(0,4)=='card') {
			var d = document.createElement('div');
			d.id = divs[i].id+'_prenip';
			if (divs[i].className=='cardmini') {
				stylePlusMini(d,divs[i]);
			} else {
                                stylePlus(d,divs[i]);
			}
			d.style.cursor='pointer';
			if (PeopleCart.contains(divs[i].id)) {
				d.innerHTML='<img id="'+divs[i].id+'_corner" src="/img/pile_dogear.gif?'+divs[i].id+'"/>';
				d.onclick = queueDn;
			} else {
				d.innerHTML='<img id="'+divs[i].id+'_corner" src="/img/pile_undogear.gif?'+divs[i].id+'"/>';
				d.onclick = queueUp;
			}

			divs[i].insertBefore(d,divs[i].childNodes[1]);
		}
	}
}  

function queueUp() {
	var handle = this.id.substr(0,this.id.indexOf('_prenip'));
	PeopleCart.add(handle);
	var d = new Date();
	var t = d.getTime();
	document.getElementById(handle+'_corner').src="/img/pile_dogear.gif?"+handle;
	document.getElementById(handle+'_prenip').onclick=queueDn;
	return false;
}

function queueDn() {
	var handle = this.id.substr(0,this.id.indexOf('_prenip'));
	PeopleCart.remove(handle);
	var d = new Date();
	var t = d.getTime();
	document.getElementById(handle+'_corner').src="/img/pile_undogear.gif?"+handle;
	document.getElementById(handle+'_prenip').onclick=queueUp;
	return false;
}

function styleDogear(d,p) {
	d.style.cssFloat='right';
	d.style.vertialAlign='top';
	d.style.position='absolute';
	d.style.top=(p.style.top-1)+'px';
	d.style.left=(p.style.left+(document.all ? 88 : 90))+'px';
	d.style.width='20px';
	d.style.height='20px';
}
function stylePlus(d,p) {
	d.style.cssFloat='right';
	d.style.vertialAlign='top';
	d.style.position='absolute';
	d.style.top=(p.style.top-1)+'px';
	d.style.left=(p.style.left+(document.all ? 86 : 88))+'px';
	d.style.width='20px';
	d.style.height='20px';
}
function stylePlusMini(d,p) {
        d.style.cssFloat='right';
        d.style.vertialAlign='top';
        d.style.position='absolute';
        d.style.top=(p.style.top-1)+'px';
        d.style.left=(p.style.left+(document.all ? 30 : 32))+'px';
        d.style.width='20px';
        d.style.height='20px';
}

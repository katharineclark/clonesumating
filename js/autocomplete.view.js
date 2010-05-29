var theDoc = document;
var bigone = new Array();
var selectorIds = new Array();

function initAutocomplete() {
        createArray(0);
}

function setSelectedText(eleId,text) {
        theDoc.getElementById(eleId).value = text;
}

function getfirstmatch(id) {
		if (document.all) { return; }
		if (theDoc.getElementById('tag').value.length) { 
			setTimeout('reset('+id+')',200);
			return; 
		}
		try {
			var sel = theDoc.getElementById('innerselector'+id);
			if (sel.childNodes.length) {
					// find one that's highlighted by using arrow keys
					for (var i=0;i<sel.childNodes.length;i++) {
							if (sel.childNodes[i].childNodes[0].className == 'selected') {
									setSelectedText('tag',sel.childNodes[0].childNodes[0].innerHTML);
									setTimeout('reset('+id+')',200);
									return;
							}
					}
					// or get the first one
					setSelectedText('tag',sel.childNodes[0].innerHTML);
			}
			setTimeout('reset('+id+')',200);
			return;
		} catch(e) {}
}

function doclick(e) {
	var ele = e.target;
	var txt = ele.innerHTML;
	var id = ele.id.substring(12).split('-');
	setSelectedText('tag',txt);
	reset(id[0]);
	return false;
}

function dohighlight(e) {
		if (!e) { e = window.event }
        e.target.className='selector_obj_highlight';
		for (var i=0;i<selectorIds.length;i++) {
			if (e.target.id != selectorIds[i]) {
				theDoc.getElementById(selectorIds[i]).className='selector_obj';
			}
		}
}

function nohighlight(e) {
		if (!e) { e = window.event }
        e.target.className='selector_obj';
}


function createArray(id) {
        bigone[id] = new Array(new Array(),new Array());
}

function addToArray(id,value,text) {
		if (!bigone[id] || !bigone[id].length) { bigone[id] = new Array(new Array(),new Array()) }
        var array = bigone[id];
        array[0].push(value);
        array[1].push(text);
}


function reset(id) {
	try {
		selectorIds = new Array();
        theDoc.getElementById('innerselector'+id).innerHTML='';
        theDoc.getElementById('selector'+id).style.display='none';
	} catch(e) {}
}
function repopulate(id,m) {
        reset(id);

        if (m[0].length == 0) {  return false; }

        var selectbox = theDoc.getElementById('selector'+id);
        selectbox.style.display='inline';
        var selectbox = theDoc.getElementById('innerselector'+id);

		selectorIds = new Array();
        for (i=0;i<m[0].length;i++) {
                var s = theDoc.createElement('div');
				s.id = 'selector_obj'+id+'-'+i;
                s.className='selector_obj';

				s.onclick=doclick;
				s.onmouseover=dohighlight;
				s.onmouseout=nohighlight;

				s.innerHTML=m[1][i];

                selectbox.appendChild(s);

				selectorIds.push(s.id);
        }
}

function stripSpaces(x) {
    while (x.substring(0,1) == ' ') x = x.substring(1);
    while (x.substring(x.length-1,x.length) == ' ') x = x.substring(0,x.length-1);
        return x;
}

// string => value from textbox, i.e. this.value
// selectbox => select object to modify, i.e. theDoc.theform.thebigselectbox
// id => array you want to use to populate the selectbox
// 
// so a typical setup: <input type='text' name='foo' onkeyup="keypress(this.value,theDoc.theform.selectboxname,0)"/>
//
var notGoing=1;
function autocompleteReturn(response) {
	if (!response || !response.getElementsByTagName('value').length) {
		reset(0);
		return;
	}
	var string = response.getElementsByTagName('string')[0].firstChild.nodeValue;
	bigone[string] = new Array();
	for (var i=0;i<response.getElementsByTagName('value').length;i++) {
		var tag = response.getElementsByTagName('value')[i].firstChild.nodeValue;
		addToArray(string,tag,tag);
	}
	notGoing = 1;
	keypress(string,0);
}

function keypress(string,id) {
		if (document.all) { return; }
        var selectbox = theDoc.getElementById('selector'+id);
        var len = string.length;
        if (!len) {
                reset(id);
                return;
        }
        string = stripSpaces(string);

        var thearray = bigone[string];
		if (!thearray || !thearray.length) {
			if (notGoing == 1) {
				notGoing = 0;
				submitRequest('tag.autocomplete','tagForm','');
				setTimeout("notGoing=1;",1000);
			}
			return;
		}

        var m = new Array(new Array(),new Array());
        if (len > 0) {
                for (i=0;i<thearray[0].length;i++) {
                        if (thearray[1][i].indexOf(string) == 0) {
                                m[1][m[1].length] = thearray[1][i];
                                m[0][m[0].length] = thearray[0][i];
                        }
                }
				if (m[1].length) {
					repopulate(id,m);
				} else {
					reset(id);
				}
        } else {
                reset(id);
        }
        return false;
}

function doalert() {
        for (i=0;i<bigone.length;i++) {
                var matcher = theDoc.getElementById('tag');
                var selector = theDoc.getElementById('selector'+i);
                if (matcher.value.length == 0) {
                        alert(i+': no input!');
                        return;
                }
                if (selector.length == 0) {
                        alert(i+': no matches.');
                        return;
                }
                var foo = selector.options[selector.selectedIndex].value;
                if (foo.length) { alert(i+": submitting value: "+foo); }
                else { alert(i+": no selections!"); }
        }
        return false;
}

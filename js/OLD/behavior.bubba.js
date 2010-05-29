var lastuserId = '';
var wipe= '';

var bubbahttp = getHTTPObject();


// Detect if the browser is IE or not.
// If it is not IE, we assume that the browser is NS.
var IE = document.all?true:false

// If NS -- that is, !IE -- then set up for mouse capture
if (!IE) document.captureEvents(Event.MOUSEMOVE)

// Set-up to use getMouseXY function onMouseMove
document.onmousemove = getMouseXY;

// Temporary variables to hold mouse x-y pos.s
var mouseX = 0
var mouseY = 0

// Main function to retrieve mouse x-y pos.s

function getMouseXY(e) {
  if (IE) { // grab the x-y pos.s if browser is IE
    mouseX = event.clientX + document.body.scrollLeft
    mouseY = event.clientY + document.body.scrollTop
  } else {  // grab the x-y pos.s if browser is NS
    mouseX = e.pageX
    mouseY = e.pageY
  }  
  // catch possible negative values in NS4
  if (mouseX < 0){mouseX = 0}
  if (mouseY < 0){mouseY = 0}  
  return true
}

function personBubba(id) {

	if (lastuserId == '')  {
	lastuserId = id;
	request = "/api.pl?method=user.get&userId=" + lastuserId;
        bubbahttp.open("GET",request,true);
        bubbahttp.onreadystatechange= showBubba;
        bubbahttp.send(null);
	
	} 
	
	return true;
}


function showBubba() {

if (bubbahttp.readyState == 4) {
        var results = bubbahttp.responseXML;
        var html = bubbahttp.responseText;
        // reset the object.
                   
        var status = results.getElementsByTagName('rsp')[0].getAttribute('stat');
                        
        if (status == "ok") {
		var bubba = document.getElementById('bubba');
		var bubbainside = document.getElementById('bubbainside');
		handle = results.getElementsByTagName('handle')[0].firstChild.nodeValue;
		photoId = results.getElementsByTagName('photoId')[0].firstChild.nodeValue;
		city = results.getElementsByTagName('city')[0].firstChild.nodeValue;
		state = results.getElementsByTagName('state')[0].firstChild.nodeValue;;
		country = results.getElementsByTagName('country')[0].firstChild.nodeValue;;

		bubbainside.innerHTML = '<h2 class="bubbatitle">' + handle + '</h2> <img src="/photos/' + lastuserId + '/100/' + photoId + '.jpg"> <BR /> <img src="http://dev.consumating.com/img/up-small.gif"> <img src="http://dev.consumating.com/img/down-small.gif">';

                bubba.style.top = mouseY - 125;  
                bubba.style.left = mouseX + 25;
		bubba.style.display = "block";

        } else if (status == "fail") {
                var error = results.getElementsByTagName('error')[0].getAttribute('msg');
                errorBox(error);
        }
}                        



}


function wipeBubba() {

	setTimeout("clearBubba()",300);
	wipe = 1;
	        bubbahttp = getHTTPObject();
	lastuserId = '';

}

function stopWipe() {
	
	wipe = '';

}

function clearBubba() {

	if (wipe == 1) {
	var bubba = document.getElementById('bubba');
	bubba.style.display = "none";
	wipe = '';
	}

}

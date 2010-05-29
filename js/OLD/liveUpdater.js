// autocomplete and related changes
// Copyright 2004 Leslie A. Hensley
// hensleyl@papermountain.org
// you have a license to do what ever you like with this code
// orginally from Avai Bryant 
// http://www.cincomsmalltalk.com/userblogs/avi/blogView?entry=3268075684

if (navigator.userAgent.indexOf("Safari") > 0)
{
  isSafari = true;
  isMoz = false;
  isIE = false;
}
else if (navigator.product == "Gecko")
{
  isSafari = false;
  isMoz = true;
  isIE = false;
}
else
{
  isSafari = false;
  isMoz = false;
  isIE = true;
}
    
function liveUpdaterUri(id, uri)
{
    function constructUri()
    {
        var separator = "?";
        if(uri.indexOf("?") >= 0)
            separator = "&";
        return uri + separator + "s=" + escape(document.getElementById(id).innerHTML);
    }
    return liveUpdater(constructUri, function () {});
}

function liveUpdaterUriFunc(id, uri, postFunc, preFunc)
{
    function constructUri()
    {
        var separator = "?";
        if(uri.indexOf("?") >= 0)
            separator = "&";
        return uri + separator + "s=" + escape(document.getElementById(id).innerHTML);
    }
    return createLiveUpdaterFunction(constructUri, postFunc, preFunc);
}


/*
  liveUpdater returns the live update function to use
  uriFunc: The function to generate the uri
  postFunc: <optional> Function to run after processing is complete
  preFunc: <option> Function to run before processing starts
*/
function liveUpdater(uriFunc, postFunc, preFunc)
{
  if(!postFunc) postFunc = function () {};
  if(!preFunc) preFunc = function () {};

  return createLiveUpdaterFunction(uriFunc, postFunc, preFunc);
}

function recreateTR(parentElement, subtree)
{
  for(var i = parentElement.childNodes.length-1; i>=0; i--)
  {
    parentElement.removeChild(parentElement.childNodes[i]);
  }

  for(var i=0; i<subtree.childNodes.length; i++)
  {
    var cell = document.createElement(subtree.childNodes[i].nodeName);
    cell.innerHTML = flattenChildren(subtree.childNodes[i].childNodes)
    parentElement.appendChild(cell);
  }
}

function createLiveUpdaterFunction(uriFunc, postFunc, preFunc)
{
    var request = false;
    if (window.XMLHttpRequest) {
        request = new XMLHttpRequest();
    }
    
    function update()
    {
        if(request && request.readyState < 4)
            request.abort();

            
        if(!window.XMLHttpRequest)
            request = new ActiveXObject("Microsoft.XMLHTTP");

        preFunc();
        request.onreadystatechange = processRequestChange;
        request.open("GET", uriFunc());
        request.send(null);
        return true;
    }

    function processRequestChange()
    {
      if(request.readyState == 4)
      {
        var xmlDoc = request.responseXML;

		if (!xmlDoc) return;

        var body = xmlDoc.getElementsByTagName("body");

        if(body.length>0)
        {
          var nodes = body[0].childNodes
          for(var i=0;i<nodes.length;i++)
          {
            if(nodes[i].nodeType==1 && nodes[i].getAttribute("id")!=null)
            {
              var id = nodes[i].getAttribute("id")
              if(isIE && nodes[i].nodeName == 'tr')
              {
                recreateTR(document.getElementById(id), nodes[i]);
              }
              else
              {
                document.getElementById(id).innerHTML = flattenChildren(nodes[i].childNodes)
              }
            }
          }
        }

        var scripts = xmlDoc.getElementsByTagName("script");
        for(var i=0;i<scripts.length;i++)
        {
          if(scripts[i].firstChild!=null)
          {
            var script = scripts[i].firstChild.nodeValue
            if(script != null)
            {
              eval(script)
            }
          }
        }
        postFunc();
      }
    }

    return update;
}

/*
  id: id of the element doing the search
  uri: URI the live search makes a call to results
  field_event_type: event in which the live search is fired
  preFunc: <option> Function to run before processing starts
  postFunc: <optional> Function to run after processing is complete
*/
function liveSearch(id, uri, field_event_type, preFunc, postFunc)
{
    function constructUri()
    {
      //TODO this needs to be refactored, possibly a type => value_getter()
      var elementValue;
      if( document.getElementById(id).type == 'checkbox' && !document.getElementById(id).checked)
      {
        // I tried to get the default value for the checbox that is in the hidden, but there is no direct coorelation
        elementValue = "false";
      }
      else if(document.getElementById(id).type == 'select-multiple')
      {
        var buffer = "";
        var aSelect = document.getElementById(id);
        for(var i=0; i<aSelect.options.length; i++)
        {
          if(aSelect.options[i].selected)
          {
            buffer = buffer + aSelect.options[i].value + "|";
          }
        }
        elementValue = escape(buffer);
      }
      else
      {
        elementValue = escape(document.getElementById(id).value);
      }

      var separator = "?";
      if(uri.indexOf("?") >= 0)
          separator = "&";
      return uri + separator + "s=" + elementValue + "&z=" + new Date().getTime();
    }

    var updater = liveUpdater(constructUri, postFunc, preFunc);
    var timeout = false;
        
    function start() {
     if (timeout)
         window.clearTimeout(timeout);
     timeout = window.setTimeout(updater, 300);
    }

  if(field_event_type == 'CHANGE')
  {
    addListener(document.getElementById(id), 'change', updater);
  }
  else if(field_event_type == 'CLICK')
  {
    addListener(document.getElementById(id), 'click', updater);
  }
  else if(field_event_type == 'BLUR')
  {
    addListener(document.getElementById(id), 'blur', updater);
  }
  else
  {
    addKeyListener(document.getElementById(id), start);
  }
}

function autocomplete(id, popupId, uri, theform)
{
    var inputField = document.getElementById(id);
    var popup = document.getElementById(popupId);
    var options = new Array(); 
    var current = 0;
    var originalPopupTop = popup.offsetTop; 
    
    function constructUri()
    {
        var separator = "?";
        if(uri.indexOf("?") >= 0)
            separator = "&";
        return uri + separator + "s=" + escape(inputField.value);
    }
   
    function hidePopup()
    {
      popup.style.visibility = 'hidden';
    }

    function handlePopupOver()
    {
      removeListener(inputField, 'blur', hidePopup);
    }
    
    function handlePopupOut()
    {
      if(popup.style.visibility == 'visible')
      {
        addListener(inputField, 'blur', hidePopup);
      }
    }
    
    function handleClick(e)
    {
      inputField.value = eventElement(e).innerHTML;
      popup.style.visibility = 'hidden';
      inputField.focus();
	  try {
		if (document.getElementById(theform).onsubmit) {
			//alert('got handler');
			var f = document.getElementById(theform).onsubmit;
			//alert(f);
			if (f()) {
				//alert('handler true');
				document.getElementById(theform).submit();
			} else {
				//alert('handler false');
				return false;
			}
		} else {
			//alert('no handler');
			document.getElementById(theform).submit();
		}
	  }catch(e){
		//alert('autcomplete handleClick error: '+e.message)
	  }
    }
    
    function handleOver(e)
    {
      options[current].className = '';
      current = eventElement(e).index;
      options[current].className = 'selected';
    }
    
    function post()
    {
        current = 0;
        options = popup.getElementsByTagName("li");
        if((options.length > 1)
           || (options.length == 1 
               && options[0].innerHTML != inputField.value))
        {
          setPopupStyles();
          for(var i = 0; i < options.length; i++)
          {
            options[i].index = i;
            addOptionHandlers(options[i]);
          }
          options[0].className = 'selected';
        }
        else
        {
          popup.style.visibility = 'hidden';
        }
    }
  
    function setPopupStyles()
    {
      var maxHeight
      if(isIE)
      {
        maxHeight = 200;
        popup.style.left = '0px';
        popup.style.top = (originalPopupTop + inputField.offsetHeight) + 'px';
      }
      else
      {
        maxHeight = window.outerHeight/3;
      }
      if(popup.offsetHeight < maxHeight)
      {
        popup.style.overflow = 'hidden';
      }
      else if(isMoz)
      {
        popup.style.maxHeight = maxHeight + 'px';
        popup.style.overflow = '-moz-scrollbars-vertical';
      }
      else
      {
        popup.style.height = maxHeight + 'px';
        popup.style.overflowY = 'auto';
      }
      popup.scrollTop = 0;
      popup.style.visibility = 'visible';
    }
    
    function addOptionHandlers(option)
    {
      addListener(option, "click", handleClick);
      addListener(option, "mouseover", handleOver);
    }
    
    var updater = liveUpdater(constructUri, post);
    var timeout = false;
   
    function start(e) {
      if (timeout)
        window.clearTimeout(timeout);
      //up arrow
      if(e.keyCode == 38)
      {
        if(current > 0)
        {
          options[current].className = '';
          current--;
          options[current].className = 'selected';
          options[current].scrollIntoView(false);
        }
      }
      //down arrow
      else if(e.keyCode == 40)
      {
        if(current < options.length - 1)
        {
          options[current].className = '';
          current++;
          options[current].className = 'selected';
          options[current].scrollIntoView(false);
        }
      }
      // tab
      else if(e.keyCode == 9 && popup.style.visibility == 'visible')
      {
        inputField.value = options[current].innerHTML;
        popup.style.visibility = 'hidden';
        inputField.focus();
        if(isIE)
        {
          event.returnValue = false;
        }
        else
        {
          e.preventDefault();
        }
      }
      else
      {
        timeout = window.setTimeout(updater, 300);
      }
    }
  addKeyListener(inputField, start);
  addListener(popup, 'mouseover', handlePopupOver);
  addListener(popup, 'mouseout', handlePopupOut);
}

/* Functions to handle browser incompatibilites */
function eventElement(event)
{
  if(isMoz)
  {
    return event.currentTarget;
  }
  else
  {
    return event.srcElement;
  }
}

function addKeyListener(element, listener)
{
  if (isSafari)
    element.addEventListener("keydown",listener,false);
  else if (isMoz)
    element.addEventListener("keypress",listener,false);
  else
    element.attachEvent("onkeydown",listener);
}

function addListener(element, type, listener)
{
  if(element.addEventListener)
  {
    element.addEventListener(type, listener, false);
  }
  else
  {
    element.attachEvent('on' + type, listener);
  }
}

function removeListener(element, type, listener)
{
  if(element.removeEventListener)
  {
    element.removeEventListener(type, listener, false);
  }
  else
  {
    element.detachEvent('on' + type, listener);
  }
}

/* XML Helper functions */
function flatten(node)
{
	if(node.nodeType == 1)
	{
		return '<' + node.nodeName + flattenAttributes(node) + '>' +
		flattenChildren(node.childNodes) + '</' + node.nodeName + '>';
	}
	else if(node.nodeType == 3)
	{
		return node.nodeValue;
	}
}

function flattenAttributes(node)
{
  var buffer = ''
  for(var i=0;i<node.attributes.length;i++)
  {
    var attribute = node.attributes[i]
    buffer += ' '+attribute.name+'="'+attribute.value+'"'
  }
  return buffer;
}

function flattenChildren(nodes)
{
	var buffer = '';
	if(nodes.length > 0)
	{
		for (var i=0;i<nodes.length;i++)
		{
			buffer += flatten(nodes[i]);
		}
	}
	return buffer;
}

function populateList(xmlobj) {


		var list = document.getElementById('popularList');
                var profiles = xmlobj.getElementsByTagName('profile');

		var title =    xmlobj.getElementsByTagName('title')[0].firstChild.nodeValue;
		list.innerHTML = '';
		var html = '<h2 class="subtitle">' + title + '</h1>';
                for (var i = 0; i < profiles.length; i++) {


			var linkhandle = profiles[i].getElementsByTagName('linkhandle')[0].firstChild.nodeValue;
                        var userId = profiles[i].getElementsByTagName('userId')[0].firstChild.nodeValue;
			if (tagline = profiles[i].getElementsByTagName('tagline')[0].firstChild) {
			var tagline = profiles[i].getElementsByTagName('tagline')[0].firstChild.nodeValue;
			} else {
			var tagline = '';
			}
			if (profiles[i].getElementsByTagName('photoId')[0].firstChild) {
                        var photoId = profiles[i].getElementsByTagName('photoId')[0].firstChild.nodeValue;
			} else {
			var photoId='';
			}
                        var city = profiles[i].getElementsByTagName('city')[0].firstChild.nodeValue;
			if ( profiles[i].getElementsByTagName('country')[0].firstChild) {
                        var country = profiles[i].getElementsByTagName('country')[0].firstChild.nodeValue;
			} else {

				var country = '';
			}
			if (country == "US") {
			          var state = profiles[i].getElementsByTagName('state')[0].firstChild.nodeValue;
			}
                        var handle = profiles[i].getElementsByTagName('handle')[0].firstChild.nodeValue;

			html = html + '<div class="popularItem"><a href="/profiles/' + linkhandle + '"><img src="http://consumating.com/photos/' + userId  + '/100/' + photoId + '.jpg" border="0" height="100" width="100" align="left" hspace="10" class="person"></A><span class="medium"><a href="/profiles/' + linkhandle + '">' + handle+ '</a></span><BR /><span class="normal"><i>' + tagline + '</i></span><BR />';

			if (country == "US") {
				html = html + '<span class="normal">' + city + ', ' + state  + '</span>';
			} else {
				html = html + '<span class="normal">' + city + ', ' + country + '</span>';
			}

			html = html + '<BR clear="all" /></div>';

			list.innerHTML = html;


		}


}

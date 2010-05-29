

	function getNewPerson()	{
	
		submitRequest("user.getRandomRecommendation","","");
		return false;
	}

	function printRecommendation(profiles) {

		var random = document.getElementById('related');

                var linkhandle = profiles.getElementsByTagName('linkhandle')[0].firstChild.nodeValue;
                var userId = profiles.getElementsByTagName('userId')[0].firstChild.nodeValue;
                // var tagline = profiles.getElementsByTagName('tagline')[0].firstChild.nodeValue;
                if (profiles.getElementsByTagName('photoId')[0].firstChild) {
	                var photoId = profiles.getElementsByTagName('photoId')[0].firstChild.nodeValue;
                } else {
                        var photoId='';
                }
                var city = profiles.getElementsByTagName('city')[0].firstChild.nodeValue;
                if ( profiles.getElementsByTagName('country')[0].firstChild) {
                        var country = profiles.getElementsByTagName('country')[0].firstChild.nodeValue;
                } else {
                        var country = '';
                }
                if (country == "US") {
                        var state = profiles.getElementsByTagName('state')[0].firstChild.nodeValue;
                }
                var handle = profiles.getElementsByTagName('handle')[0].firstChild.nodeValue;
		var type = profiles.getElementsByTagName('type')[0].firstChild.nodeValue;


		var HTML = '<div class="card" style="float:left;"><a href="/profiles/' + linkhandle + '"><img src="/photos/' + userId + '/100/' + photoId + '.jpg" width="100" height="100" border="0"><BR /><span class="small">' + handle + '</a><BR />' + city + ', ';
		if (country == "US") { HTML = HTML + state} else { HTML = HTML + country; }
		HTML = HTML + '</span></div> <P class="large">';

		if (type == "quirky") {
			HTML = HTML + '<a href="/profiles/' + linkhandle + '">' + handle + '</a> has some of the same obscure interests as you.</p>';
		} else if (type == "similar") {
                        HTML = HTML + '<a href="/profiles/' + linkhandle + '">' + handle + '</a> has a lot of the same tags as you.</p>';
		}

		HTML = HTML + '<BR clear="all" />';

		random.innerHTML = HTML;
	
		return false;


	}

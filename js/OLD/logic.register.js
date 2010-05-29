function overlapHandle(xmlobj) {

    document.getElementById('handle').value = '';
    document.getElementById('handle').focus();
	errorBox("Oops!  The handle you chose is already in use by someone else.  Please pick another one!");

}


function overlapEmail(xmlobj) {

	if (confirm('Oops! The e-mail address you entered is already in our database!  Click "OK" to continue to the login page, or "Cancel" to enter a new e-mail!')) {
		document.location='/login.pl';
	} else {
		document.getElementById('username').value = '';
	}
}






function locationToggle() {

        var country = document.getElementById('country').options[ document.getElementById('country').selectedIndex].value;

        if (country == "US") {
                document.getElementById('usa_location').style.display = 'block';
                document.getElementById('foreign_location').style.display = 'none';
        } else {
                document.getElementById('usa_location').style.display = 'none';
                document.getElementById('foreign_location').style.display = 'block';
        }

}


function validateReturn(xmlobj) {

//   <usernameTaken>email</usernameTaken>
//   <handleTaken>handle</handleTaken>
//   <validate>OK|FAIL</validate>
//   <badField>fieldname</badField>
	
	try {
		resetHighlight();
		if (xmlobj.getElementsByTagName('validate')[0].firstChild.nodeValue == 'FAIL') {
			if (xmlobj.getElementsByTagName('usernameTaken')[0]) {
				errorHighlight('username');
			}
				if (xmlobj.getElementsByTagName('handleTaken')[0]) {
						errorHighlight('handle');
				}
			var badfields = xmlobj.getElementsByTagName('badField');
			var i;
			for (i=0; i < badfields.length; i++) {
				errorHighlight(badfields[i].firstChild.nodeValue);
			}

			errorBox('Uh oh!  Some of the values you entered failed our validation tests.  Problem fields are highlighted in red.');
			return false;
		} else {
			document.getElementById('registerForm').submit();
			return true;
		}
	} catch(e){alert(e.message)}
}


function errorHighlight(field) {

	var label = document.getElementById(field + "Label");
	label.className='errorHighlightLabel';

}


function resetHighlight() {

        var ps = new Array;
        ps = document.getElementsByTagName('p');

        for (i = 0; i < ps.length; i++) {
                if (ps[i].className=='errorHighlightLabel') {
			ps[i].className='label';
		}
	}
	
}



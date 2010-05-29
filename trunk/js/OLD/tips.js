var tagtips = new Array("zombies","tattoos","books","music","film","indierock","cartoons","adultswim","tetris");

var tips = new Array("You can increase your popularity by writing clever answers to <a href='/qow.pl'>the weekly questions</a>.","You can have up to 5 photos displaying on your profile. <a href='/photos.pl'>Add more!</a>","Your popularity is calculated based on how many people give your profile a thumbs-up.","You can remove tags from your profile by clicking the little x next to the tag on your profile.","Have you checked your <a href='/popular/'>popularity</a> lately?","Check out <a href='/popular/'>Today's Top Ten</a>.");

//var promotips = new Array("Find interesting people to <a href='/browse/kissing'>kiss</a>. For free.","Literally hundreds of <a href='/browse/underwear'>fully clothed</a> <a href='/browse/nerd'>nerds</a> inside.","<a href='/qow.pl?question=40'>Sitcom</a>-worthy dates found inside.","OMG, we love your glasses! ","Get tagged at Consumating.com","Join for free and find other weirdos like you today!","<A href='/browse/videogames/f'>Girls who play videogames</a>, now available.","<A href='/browse/zombies'>Zombie lovers</a> apply within.","<a href='/browse/webdesign'>Find a web designer</a> to make out with.");

var promotips = new Array("Find People Who Don't Suck","Join the Bored-at-Work Generation!","Get Tagged at Consumating.com");

var welcometips = new Array("Howdy,","Welcome back,","Hey there,","What's up,","Party, party,");

var toolbartip = new Array("");

function toolbarTip() {
		index = Math.floor(Math.random() * toolbartip.length);
		document.write(toolbartip[index]);
}

function displayTip() {

        index = Math.floor(Math.random() * tips.length);
        document.write(tips[index]);
}


function promoTip() {

        index = Math.floor(Math.random() * promotips.length);
        document.write('<a href="/register.pl">' + promotips[index] + '</a>');

}


function welcomeTip() {

        index = Math.floor(Math.random() * welcometips.length);
        document.write(welcometips[index]);

}


function tagTip() {
        var index = Math.floor(Math.random() * tagtips.length);
		document.getElementById('searchtag').value = tagtips[index];
}

# Introduction #

Read this before you do anything.


# SYSTEM REQUIREMENTS #

> Apache with mod\_perl
> FastCGI (FCGI and CGI::Fast)
> Memcache
> Mysql
> Image::Magick
> All Perl modules required should be freely available at http://search.cpan.org


# CONFIGURING CONSUCODE TO WORK ON YOUR SERVER #

  1. Install all the code and images into a web root somewhere
> 2. Make changes to your apache config so that the mod\_perl modules get mapped correctly
> 3. Make sure your photos dir is writable by your web server
> 4. Make sure your img/toys dir is writable by your web server
> 5. Import database schema into your mysql server
> 6. Update lib/CONFIG.pm with database login, domain names, paths, etc
> 7. HACK TIL IT WORKS
> 8. Modify templates in /front/
> 9. Modify styles in /css/
  1. . There are a few cron jobs in /admin/cron/  They need to be set up to run regularly.


# CUSTOMIZING CATEGORIES, ETC #

  1. You'll want to fill a few databases with categories for your users.
> > => topicChannels - a list of all channels a topic can be in

> 2. In the /admin/ dir, there are a few simple admin tools.
    1. qow.pl - creates new questions of the week
> > 2. photoContest.pl - creates new photo contests, archives old ones.
> > 3. spammers.pl - this is the queue of people who have been reported as spammers

> 3. There are a bunch of email alerts and notifications in /front/emails and /front/alerts


# EXPERIMENTAL CODE #
> There is some fun, slightly newer versions of the peeps page, play page, etc in the EXPERIMENTAL dir.
> None of this stuff will work out of the box, but you can see where the code is going.

# KNOWN ISSUES #

  1. The drawing tool does not work in IE. It may look like it is working, but it will fail in the end.
> 2. Sometimes, toys mysteriously disappear. I think this has to do with them moving instead of copying.
> 3. Sometimes, posting to a topic doesn't work, or it posts double.
> 4. Misc javascript errors from time to time.
> 5. Sometimes the verification emails get lost. We hear that the date on the emails may be totally jacked.
> 6. No admin tool for simple user problems
> 7. Message points do not reset automatically at beginning of month
> 8. New Question and new photo contest alerts do not automatically send
> 9. There is no easy way to invite people to meetings


SHORT TERM PLANS

  1. Modularize functionality further so that things like tags, toys, photo contest, question of the week are
> > reasonably plug and play

> 2. Merge / improve tag pages and people browser.  New interface required to expose all the fun stuff
> > with tag quirkyness and tag combinations

> 3. Better default set of templates and styles
> 4. Kill remaining perl and fastcgi so that everything is mod\_perl
> 5. Admin tools suite



REQUIRED COMPONENTS NOT INCLUDED IN RELEASE PACKAGE:
> Prototype Javascript library.  Download and install in /js/ directory
> http://prototypejs.com/

> Scriptaculous Javascript library.  Download and install in /js/ directory
> http://script.aculo.us/

> Measuremap Sliding Graph thinger.   Download and install in /popular/
> http://www.measuremap.com/developer/slider/

> The code as it stands was built to utilize VideoEgg for video sharing.  You will have to
> become a VideoEgg partner before you can use the same code.  I recommend finding your own
> video hosting solution and modifying the code.   But VideoEgg rules.

> Zip Proximity Database.   The localization stuff will not work until you provide some
> method for deciding what local means.  Traditionally we have used a database that
> cross references zip codes to local zip codes.  You can do this however you like -
> just make sure the local queries get updated.

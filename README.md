cron2english
============

Cron2English is a Ruby library for turning crontab schedules into English text.

It is roughly a Ruby port of Sean Burke's [crontab2english](www.cpan.org/authors/id/S/SB/SBURKE/crontab2english_0.71.pl) Perl script, except its interface is a Ruby method rather than an executable, and it parses only time specs, not all the other things you might find in a crontab (comments, variable definitions, and the commands to run).

Usage
-----

You can convert a time spec to English like so:

    english = Cron2English.parse("40 5 * * *")

This will yield an array of strings, in this case the following:

    ["5:40am", "every day"]

These strings are chosen so as to sound vaguely human if you say:

    Cron2English.parse("40 5 * * *").join(" ")

Cron2English understands just about anything you'll find in a crontab, including non-POSIX extensions. It can parse:

* `1-20/3 * * * *`
* `1,2,3 * * * *`
* `1-9,15-30 * * * *`
* `1-9/3,15-30/4 * * * *`
* `1 2 3 4 mON`
* `1 2 3 jan 5`
* `@reboot`
* `@yearly`
* `@annually`
* `@monthly`
* `@weekly`
* `@daily`
* `@midnight`
* `@hourly`
* `*/3 * * * *`

Known Issues
------------

None yet!


Contributing to Cron2English
-----------------------------
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone hasn't already requested and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make be sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, that is fine, but please isolate that change to its own commit so I can cherry-pick around it.

Commands for building/releasing/installing:

* `rake build`
* `rake install`
* `rake release`

Copyright
---------

Copyright (c) 2014 Paul A. Jungwirth.
See LICENSE.txt for further details.


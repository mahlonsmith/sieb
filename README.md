
Sieb
====

Streamlined mail filtering and delivery.


What's this?
------------

I used procmail for nearly 25 years.  In time, I migrated to maildrop.  Had some
minor frustrations, and finally just decided to scratch my own itch.  Maybe you're
itchy too?  This might scratch it. It might not.  Read on to find out.

Sieb is nowhere near as functional as procmail or maildrop, but it is geared
specifically for how -I- used those tools, which in 25 years, definitely covers
my primary use case - and no others.

Here's what Sieb is good at:

  - Matching email on arbitrary headers, and delivering to Maildir.
  - Piping messages through "filters" dedicated for that purpose - formail,
    spamprobe, bogofilter, etc
  - Caring about your mail: any fatal exception throws the message back to the MTA queue
  - Runtime exceptions deliver the message to the default `$HOME/Maildir`
  - Efficiency:  Written in Nim for speed, deliveries on modern hardware generally
    are under 10ms and consume around 16k of memory

Other behaviors to be aware of -- to be considered features, or perhaps reasons
to steer clear:

  - Designed for use with Qmail.  Presumably you can use it with other MTAs,
    but I haven't tested it.  YMMV.
  - Only supports Maildir.  I haven't used an MBox since 1998 and I don't intend to.
  - There is no mail forwarding logic.  Just filtering and delivery.
  - Deliveries to Maildir are always presumed to be relative under `$HOME/Maildir`,
    as 'child' Maildirs. This is for interaction with Maildir-aware environments
    such as Dovecot, and keeps all your email to one tidy spot.
  - Maildir delivery paths are always created automatically if not already
	present, no need to worry about maildirmake nonsense.
  - Sieb only filters email on RFC2822 headers.  SMTP bodies are not considered.
  - There are roughly two "phases", both are optional - matching before an
	external filter, and matching afterwards.  This is for delivery before and
	after an out-of-band spam filter.
  - Sieb can be used as a system-wide default delivery agent, for site specific
    delivery instructions.  Users can override the side-wide settings, following
	the Qmail mantra.
  - There is no custom programming "language" to learn - no conditionals, no
    variables.  Just a YAML file expressing delivery instructions.


Installation
------------

You can check out the current development source with Fossil via its
[home repo](https://code.martini.nu/fossil/sieb), or with Git at its
[project mirror](https://github.com/mahlonsmith/sieb).

Alternatively, you can download the latest version [directly](https://code.martini.nu/fossil/sieb/uv/release/sieb-latest.tar.gz).

With the [nim](https://nim-lang.org/) environment installed and the Sieb
repository cloned, simply type:

    % make

That will result in an optimized `sieb` binary.  Put it into your $PATH.


Then simply instruct Qmail to deliver to Sieb - either site-wide, or for
yourself via a `.qmail` file as such:

    | /path/to/sieb


By default, Sieb delivers to `$HOME/Maildir` as if it wasn't there at all.  In
order to control behavior, you'll need a configuration file.  You can generate a
commented example file and put it where Sieb can find it as such:

    % mkdir -p ~/.config/sieb && sieb -g > ~/.config/sieb/config.yml


Configuration
-------------

Sieb uses a YAML file to describe filtering and delivery behavior.

It looks for a file in the following locations:

      - ~/.config/sieb/config.yml
      - /usr/local/etc/sieb/config.yml
      - /etc/sieb/config.yml

You can also specify a file via the `-c (--conf)` flag:

    % sieb --conf=/path/to/config.yml

Without a config file, Sieb is transparent.


There are only three things to know for Sieb config -- rules, filters, and
delivery destinations.


### Filters

A filter is a pipe to an external program.  It should accept input on stdin, and
emit on stdout.

You can have any number of filters, either globally, or specific to a successful
match.

Filters are expressed as a YAML array, so you don't need to worry about escaping
shell quotes, for example, for complex arguments.

An example global filter chain that performs spam categorization, then adds a
custom header:

    filter:
      - [ bogofilter, -uep ]
      - [ reformail, -A, "X-Sieb: Processed!" ]


### Delivery Destination

Simply, the name of the child maildir to put a matched email into.  This is
always relative to `$HOME/Maildir`:

    deliver: .freebsd

In the above example, a matching rule would deliver the message to:

    ~/Maildir/.freebsd/new/

In the absence of a delivery instruction, mail is delivered to `$HOME/Maildir`.


### Rules

A rule is the workhorse, combining filters and delivery destinations.  They are
expressed as an array of YAML key/val pairs. Each key represents a header, each
value is a [PCRE-style](http://pcre.org/current/doc/html/pcre2pattern.html)
regular expression to test the header against.  If there are multiple headers
listed for a rule, all must match.  Headers (and the regular expressions) are
compared case-insensitively.

Rules are executed top down, first match wins.

    rules:
      - 
        match:
          subject: whatever
        filter:
          - [ reformail, -A, "X-Sieb: Matched!" ]
        deliver: .whatever-mail

There is a special key called "TO", that matches both "To:" and "Cc:" headers
simultaneously for convenience.  Keep in mind that mail addresses can include
quotes, real names, etc.  Use greedy matching!

      - 
        match:
          TO: .*freebsd-questions@FreeBSD.org.*
        deliver: .freebsd-lists


The YAML parser is (extremely) strict.  If something doesn't seem to be working,
it's likely due to an error in your YAML - which brings me to...


Debugging
---------

You can use the `-l (--log)` flag to instruct Sieb to write out what it is
doing, along with any errors along the way.  Note that the logfile must remain
locked during delivery, so it can slow simultaneous deliveries if you've got a
busy incoming mailbox.

The logfile is always written under `$HOME/Maildir`, so `--log=sieb.log` ends up
at:

    ~/Maildir/sieb.log

If you're having a particularly hard time filtering a piece of mail, you can
feed it into sieb directly with the `--debug` flag, and the same information
will be emitted to stdout.  This is useful both when diagnosing a filter, and
when trying out a new one without affecting current mail delivery.  You'll
probably want to avoid this flag in production, as it'll likely fill your mail
logs with garbage.  Sieb is silent by default.

    % sieb -d < test-message.txt

    2023-07-01T01:50:22Z ------------------------------------------------------------------
    Using configuration at: config.yml
    Opening new message at:
      /home/mahlon/Maildir/tmp/1688176222.263185.1583965.1.kazak
    Wrote 9623 bytes
    Parsed message headers.
    Message-ID is "<a111b6a7-0bf8-d3b9-9611-a7fbf36635b3@artem.ru>"
    Evaluating rule...
     checking header "list-id"
        match on ".*freebsd-questions.*"
    Rule match!
    Delivered message to:
      /home/mahlon/Maildir/.freebsd/new/1688176222.263185.1583965.1.kazak
    Completed in 1.14ms, using 18.02Kb


Reporting Issues
----------------

Please report any issues [here](https://code.martini.nu/fossil/sieb/tktnew).


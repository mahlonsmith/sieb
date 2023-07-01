# vim: set et nosta sw=4 ts=4 :
#
# Various helper functions that don't have a better landing spot.
#

#############################################################
# I M P O R T S
#############################################################

import
    std/parseopt,
    std/terminal,
    std/strutils

import
   logging


#############################################################
# C O N S T A N T S
#############################################################

const
    VERSION = "v0.1.0"
    USAGE = """
./sieb [-c] [-d] [-h] [-v]

  -c --conf:
    Use a specific configuration file.  Otherwise, files are
    attempted in the following order:
      - ~/.config/sieb/config.yml
      - /usr/local/etc/sieb/config.yml
      - /etc/sieb/config.yml

  -d --debug:
    Debug: Be verbose while parsing.

  -g --generate:
    Emit an example configuration file to stdout.

  -h --help:
    Help.  You're lookin' at it.

  -l --log:
    A file to record actions to, relative to $HOME/Maildir.

  -v --version:
    Display version number.
    """
    EXAMPLECONFIG = """
#
# Example Sieb configuration file.
#
# This file performs no actions by default, edit to taste.
#

 
## Rules tried before global filtering is applied.
## You can use this section to deliver before a spamfilter, for example.
##
# early_rules:
#
#   # Mail that is both from me and to me is questionable....
#   -
#     match:
#       from: mahlon@martini.nu
#       # Magic "TO" which means To: OR Cc:
#       TO: mahlon@martini.nu
#     filter:
#       - [ reformail, -A, "X-Sieb: I sent mail to myself?" ]
#     deliver: .suspicious
#
#  # No need to spam filter from the FreeBSD mailing list
#  -
#    match:
#      list-id: .*freebsd-questions.*
#    deliver: .freebsd



## Global filtering.  All incoming mail that didn't match an "early rule" gets
## this treatment.
##
# filter:
#   - [ bogofilter, -uep ]



## Normal rules, after the global filtering.
## Multiple matches are AND'ed.  Everything is case insensitive.
##
## Delivery default is ~/Maildir, any set value is an auto-created maildir under
## that path.
##
# rules:
#   # More mailing lists, after filters
#   -
#     match:
#       list-id: .*lists.linuxaudio.org.*
#     deliver: .linuxaudio
#
#   # Bye, spam.  (Custom bogofilter header?)
#   -
#     match:
#       x-spamfilter: \+
#     deliver: .spam
#
#   # Just filter the message and deliver to default.
#   -
#     match:
#       x-weird-example: hey, why not
#       filter:
#         - [ reformail, -A, "X-Sieb: Well alright then" ]

    """

#############################################################
# T Y P E S
#############################################################

type Opts = object
    config*: string  # The path to an explicit configuration file.
    debug*:  bool    # Explain what's being done.
    logfile*: string # Log actions to disk.


#############################################################
# G L O B A L  E X P O R T S
#############################################################

var opts*: Opts


#############################################################
# M E T H O D S
#############################################################

proc hl( msg: string, fg: ForegroundColor, bright=false ): string =
    ## Quick wrapper for color formatting a string, since the 'terminal'
    ## module only deals with stdout directly.
    if not isatty(stdout): return msg

    var color: BiggestInt = ord( fg )
    if bright: inc( color, 60 )
    result = "\e[" & $color & 'm' & msg & "\e[0m"


proc deferral*( msg: string ) =
    ## Exit with Qmail deferral code immediately.
    echo msg.replace( "\n", " - " ).hl( fgRed, bright=true )
    quit( 1 )


proc debug*( msg: string, args: varargs[string, `$`] ) =
    ## Emit +msg+ if debug mode is enabled, coercing arguments into a string for
    ## formatting.
    if opts.debug or not logger.closed:
        var str = msg % args
        if opts.debug: echo str
        if not logger.closed: str.log


proc parseCmdline*() =
    ## Populate the opts object with the user's preferences.

    # Config object defaults.
    #
    opts = Opts(
        config: "",
        debug: false,
        logfile: ""
    )

    # always set debug mode if development build.
    opts.debug = defined( debug )

    for kind, key, val in getopt():
        case kind

        of cmdArgument:
            discard

        of cmdLongOption, cmdShortOption:
            case key
                of "conf", "c":
                    opts.config = val

                of "debug", "d":
                    opts.debug = true

                of "generate", "g":
                    echo EXAMPLECONFIG
                    quit( 0 )

                of "help", "h":
                    echo USAGE
                    quit( 0 )

                of "log", "l":
                    opts.logfile = val

                of "version", "v":
                    echo "Sieb " & VERSION
                    quit( 0 )

                else: discard

        of cmdEnd: assert( false ) # shouldn't reach here


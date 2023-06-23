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

  -h --help:
    Help.  You're lookin' at it.

  -v --version:
    Display version number.
    """

#############################################################
# T Y P E S
#############################################################

type Opts = object
    config*: string # The path to an explicit configuration file.
    debug*:  bool   # Explain what's being done.


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
    if defined( debug ) or not logger.closed:
        var str = msg % args
        if defined( debug ): echo str
        if not logger.closed: str.log


proc parse_cmdline*: Opts =
    ## Populate the opts object with the user's preferences.

    # Config object defaults.
    #
    result = Opts(
        config: "",
        debug: false
    )

    # always set debug mode if development build.
    result.debug = defined( debug )

    for kind, key, val in getopt():
        case kind

        of cmdArgument:
            discard

        of cmdLongOption, cmdShortOption:
            case key
                of "conf", "c":
                    result.config = val

                of "debug", "d":
                    result.debug = true

                of "help", "h":
                    echo USAGE
                    quit( 0 )

                of "version", "v":
                    echo "Sieb " & VERSION
                    quit( 0 )

                else: discard

        of cmdEnd: assert( false ) # shouldn't reach here



# vim: set et nosta sw=4 ts=4 :

#
# Methods for finding and parsing sieb rules from YAML.
#

#############################################################
# I M P O R T S
#############################################################

import
    std/os,
    std/streams,
    std/tables,
    yaml/parser,
    yaml/serialization

import util


#############################################################
# C O N S T A N T S
#############################################################

const CONFFILES = @[
    "/usr/local/etc/sieb/config.yml",
    "/etc/sieb/config.yml"
]


#############################################################
# T Y P E S
#############################################################

type
    Rule* = object
        comment* {.defaultVal: ""}: string
        match* {.defaultVal: initTable[string, string]()}: Table[ string, string ]
        deliver* {.defaultVal: ""}: string
        filter* {.defaultVal: @[]}: seq[ seq[string] ]

    # Typed configuration file layout for YAML loading.
    Config* = object
        filter* {.defaultVal: @[]}:      seq[ seq[string] ]
        early_rules* {.defaultVal: @[]}: seq[Rule]
        rules* {.defaultVal: @[]}:       seq[Rule]


#############################################################
# M E T H O D S
#############################################################

proc parse( path: string ): Config =
    ## Return a parsed configuration from yaml.
    "Using configuration at: $#".debug( path )
    let stream = newFileStream( path )
    try:
        stream.load( result )
    except YamlParserError as err:
        debug err.msg
        return Config() # return empty default, it could be "half parsed"
    except YamlConstructionError as err:
        err.msg.debug
        return Config()
    except YamlStreamError as err:
        err.msg.debug
        return Config()
    finally:
        stream.close


proc getConfig*( path: string ): Config =
    ## Choose a configuration file for parsing, or if there are
    ## none available, return an empty config.
    if path != "":
        if not path.fileExists:
            "Configfile \"$#\" unreadable, ignoring.".debug( path )
            return
        return parse( path )

    else:
        # No explicit path given, walk the hardcoded paths to
        # try and find one.
        let homeconf = @[ getConfigDir() & "sieb/config.yml" ]
        let configs = homeconf & CONFFILES
        for conf in configs:
            if conf.fileExists:
                return parse( conf )


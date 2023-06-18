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
    std/strformat,
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
    rule = object
        headers {.defaultVal: initTable[string, string]()}: Table[ string, string ]
        deliver {.defaultVal: "Maildir"}: string
        filter {.defaultVal: ""}: string

    # Typed configuration file layout for YAML loading.
    Config* = object
        logfile {.defaultVal: "".}: string
        pre_filter {.defaultVal: @[]}: seq[string]
        post_filter {.defaultVal: @[]}: seq[string]
        rules {.defaultVal: @[]}: seq[rule]


#############################################################
# M E T H O D S
#############################################################

proc parse( path: string ): Config =
    ## Return a parsed configuration from yaml.
    debug "Using configuration at: {path}".fmt
    let stream = newFileStream( path )
    try:
        stream.load( result )
    except YamlParserError as err:
        debug err.msg
        return Config() # return empty default, it could be "half parsed"
    except YamlConstructionError as err:
        debug err.msg
        return Config()
    finally:
        stream.close


proc get_config*( path: string ): Config =
    ## Choose a configuration file for parsing, or if there are
    ## none available, return an empty config.
    if path != "":
        if not path.fileExists:
            debug "Configfile \"{path}\" unreadable, ignoring.".fmt
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


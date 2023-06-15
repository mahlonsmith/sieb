# vim: set et nosta sw=4 ts=4 :

import
    std/streams,
    yaml/serialization

const
    VERSION = "v0.1.0"

type
    rule = object
        headers: seq[ tuple[ header: string, regexp: string ] ]
        deliver {.defaultVal: "Maildir"}: string
        filter {.defaultVal: ""}: string

    # Typed configuration file layout for YAML loading.
    Config = object
        logfile {.defaultVal: "".}: string
        pre_filter {.defaultVal: @[]}: seq[string]
        post_filter {.defaultVal: @[]}: seq[string]
        rules {.defaultVal: @[]}: seq[rule]


var conf: Config

let s = newFileStream( "config.yml" )
load( s, conf )
s.close

echo conf


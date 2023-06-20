# vim: set et nosta sw=4 ts=4 :

import
    std/os,
    std/strformat

import
    lib/config,
    lib/message,
    lib/util


# Without this, we got nuthin'!
if not existsEnv( "HOME" ):
    deferral "Unable to determine HOME from environment."

let
    home    = getHomeDir()
    opts    = parse_cmdline()
    conf    = get_config( opts.config )
    default = newMaildir( joinPath( home, "Maildir" ) )

# let dest = default.subDir( "woo" )
var msg = default.newMessage
msg.writeStdin
for filter in conf.pre_filter:
    debug "Running pre-filter: {filter}".fmt
    msg = msg.filter( filter )
msg.save()


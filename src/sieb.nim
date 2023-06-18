# vim: set et nosta sw=4 ts=4 :

import
    std/os

import
    lib/config,
    lib/maildir,
    lib/util


if not existsEnv( "HOME" ):
    deferral "Unable to determine HOME from environment."

let
    home    = getHomeDir()
    opts    = parse_cmdline()
    conf    = get_config( opts.config )
    default = newMaildir( home & "Maildir" )

let dest = default.subDir( ".wooo" )

let msg = default.newMessage
msg.writeStdin()
# msg.filter()
msg.save( dest )



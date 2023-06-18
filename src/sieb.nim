# vim: set et nosta sw=4 ts=4 :

import
    std/os,
    std/streams

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


echo repr default.newMessage

# let input = stdin.newFileStream()
# var buf = input.readStr( 8192 )
# var message = buf
# while buf != "":
#     buf = input.readStr( 8192 )
#     message = message & buf

# echo message


# vim: set et nosta sw=4 ts=4 :

import
    std/os

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


# Create a new message under Maildir/tmp, and stream stdin to it.
var msg = default.newMessage.writeStdin

# If there are "early rules", parse the message now and walk those.
if conf.early_rules.len > 0:
    if msg.walkRules( conf.early_rules, default ): quit( 0 )

# Apply any configured global filtering.
for filter in conf.filter: msg = msg.filter( filter )

# Walk the rules, and if nothing hits, deliver to fallthrough.
if conf.rules.len > 0:
    if not msg.walkRules( conf.rules, default ): msg.save
else:
    msg.save

quit( 0 )


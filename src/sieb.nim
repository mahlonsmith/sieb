# vim: set et nosta sw=4 ts=4 :

#############################################################
# I M P O R T S
#############################################################

import
    std/exitprocs,
    std/os

import
    lib/config,
    lib/logging,
    lib/message,
    lib/util


#############################################################
# S E T U P
#############################################################

# Without this, we got nuthin'!
if not existsEnv( "HOME" ):
    deferral "Fatal: Unable to determine HOME from environment."

# Populate $opts
parseCmdline()

let
    home    = getHomeDir()
    default = newMaildir( joinPath( home, "Maildir" ) )

# Open the optional log file.
if opts.logfile != "": createLogger( default.path, opts.logfile )

# Exit hook - clean up any open logger filehandle.
var finalTasks = proc: void =
    if not logger.closed: logger.close
finalTasks.addExitProc


#############################################################
# M A I N
#############################################################

# Parse the YAML ruleset.
let conf = getConfig( opts.config )

# Create a new message under Maildir/tmp, and stream stdin to it.
var msg = default.newMessage.writeStdin

# If there are "early rules", parse the message now and walk those.
#
if conf.early_rules.len > 0:
    if msg.evalRules( conf.early_rules, default ): quit( 0 )

# Apply any configured global filtering.
for filter in conf.filter: msg = msg.filter( filter )

# Walk the rules, and if nothing hits, deliver to fallthrough.
#
if conf.rules.len > 0:
    if not msg.evalRules( conf.rules, default ): msg.save
else:
    msg.save

quit( 0 )


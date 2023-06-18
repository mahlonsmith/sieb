# vim: set et nosta sw=4 ts=4 :
#
# A class that represents an individual Maildir.
#

#############################################################
# I M P O R T S
#############################################################

import
    std/os,
    std/streams,
    std/strformat,
    std/times

import
    util


#############################################################
# T Y P E S
#############################################################

# A Maildir object.
#
type Maildir* = ref object
    path*: string # Absolute path to the encapsualting dir
    cur:  string
    new:  string
    tmp:  string

# An email message, under a specific Maildir.
#
type Message* = ref object
    dir:    Maildir
    path:   string
    stream: FileStream


#############################################################
# M E T H O D S
#############################################################

proc newMaildir*( path: string ): Maildir =
    ## Create and return a new Maildir object, making it on-disk if necessary.
    result = new Maildir
    result.path = path
    result.cur  = path & "/cur"
    result.new  = path & "/new"
    result.tmp  = path & "/tmp"

    if not dirExists( path ):
        let perms = { fpUserExec, fpUserWrite, fpUserRead }
        debug "Creating new maildir at {path}.".fmt
        try:
            for p in [ result.path, result.cur, result.new, result.tmp ]:
                p.createDir
                p.setFilePermissions( perms )

        except CatchableError as err:
            deferral "Unable to create Maildir: ({err.msg}), deferring delivery.".fmt


proc newMessage*( dir: Maildir ): Message =
    ## Create and return a Message - an open FileStream under a specific Maildir
    ## (in tmp)
    result = new Message

    let now = getTime()
    result.dir = dir
    result.path = dir.path & dir.tmp & '/' & $now.toUnixFloat()



# make new message (tmp)
# save message (move from tmp to new)


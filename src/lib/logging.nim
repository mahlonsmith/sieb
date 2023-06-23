# vim: set et nosta sw=4 ts=4 :
#
# A global logger.  Just write stuff to disk safely.
#

#############################################################
# I M P O R T S
#############################################################

import
    std/os,
    std/posix,
    std/times


#############################################################
# T Y P E S
#############################################################

type Logger = object
    fh: File


#############################################################
# G L O B A L  E X P O R T S
#############################################################

var logger*: Logger


#############################################################
# M E T H O D S
#############################################################

proc createLogger*( path: string ): void =
    ## Get in line to open a write lock to the configured logfile at +path+.
    ## This will block until it can get an exclusive lock.
    let path  = joinPath( getHomeDir(), path )
    logger    = Logger()
    logger.fh = path.open( fmAppend )

    # Wait for exclusive lock.
    discard logger.fh.getFileHandle.lockf( F_LOCK, 0 )
    logger.fh.writeLine "\n-------------------------------------------------------------------"
    logger.fh.writeLine now().utc


proc close*( l: Logger ): void =
    ## Release the lock and close/flush the file.
    discard l.fh.getFileHandle.lockf( F_ULOCK, 0 )
    l.fh.close()


proc closed*( l: Logger ): bool  =
    ## Returns +false+ if the logfile has been opened.
    return l.fh.isNil


proc log*( msg: string ): void =
    ### Emit a line to the logfile.
    if logger.closed: return
    logger.fh.writeLine( msg )


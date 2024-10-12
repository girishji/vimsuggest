vim9script

# This Vim9 script defines functions for asynchronous command execution.
# It provides 'Start()' to run a command with callbacks and optional timeout,
# and 'Stop()' to terminate the running job. The script handles output
# processing, implements a polling mechanism, and manages job lifecycle.

import autoload '../cmd.vim'

var jobid: job

export def Start(cmdany: any, CallbackFn: func(list<any>),
        timeout: number = 2000, max_items: number = -1)
    Stop('kill')
    var items = []
    var start_time = reltime()
    var poll_start = reltime()
    jobid = job_start(cmdany, {
        out_cb: (ch, str) => { # Invoked when channel reads a line
            items->add(str)
            if max_items != -1 && items->len() > max_items
                Stop()
            elseif poll_start->reltime()->reltimefloat() * 1000 > 100 # millisec
                # Note: In 100ms 'grep' can gather ~50k items.
                poll_start = reltime()
                if cmd.state == null_object ||
                        start_time->reltime()->reltimefloat() * 1000 > timeout
                    Stop()
                    return
                endif
                CallbackFn(items)
            endif
        },
        close_cb: (ch) => { # Invoked when no more output is available
            if cmd.state != null_object
                CallbackFn(items)
            endif
        },
    # Do not print error here since echoerr will stop the job. 'find' can
    # throw 'Operation not permitted' error. Can use '2>/dev/null' to
    # ignore stderr from 'find', but needs a shell to run the command ('sh -c').
    # err_cb: (chan: channel, msg: string) => {
    #     :echoerr $'error: {msg}'
    # },
    })
enddef

export def Stop(how = null_string)
    if jobid->job_status() ==# 'run'
        if how == null_string
            jobid->job_stop()
        else
            jobid->job_stop(how)
        endif
    endif
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

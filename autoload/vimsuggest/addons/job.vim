vim9script

import autoload '../cmd.vim'

var jobid: job

export def Start(cmdany: any, CallbackFn: func(list<any>),
        timeout: number = 2000, max_items: number = 1000)
    Stop('kill')
    var items = []
    var job_start = reltime()
    var poll_start = reltime()
    jobid = job_start(cmdany, {
        out_cb: (ch, str) => { # Invoked when channel reads a line
            items->add(str)
            if poll_start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
                if cmd.state == null_object || cmd.state.pmenu.Hidden()
                    Stop()
                    return
                endif
                if items->len() > max_items ||
                        job_start->reltime()->reltimefloat() * 1000 > timeout
                    Stop()
                endif
                CallbackFn(items)
                # this._ProcessItems(this._items, max_items)
                poll_start = reltime()
            endif
        },
        close_cb: (ch) => { # Invoked when no more output is available
            CallbackFn(items)
        },
    # Do not print error here since it will stop the job. 'find' can
    # throw 'Operation not permitted' error. Can use '2>/dev/null' to
    # redirect stderr, but need to set shell prefix to 'sh -c'.
    # err_cb: (chan: channel, msg: string) => {
    #     :echoerr $'error: {msg}'
    # },
    })
enddef

export def Stop(how: string = null_string)
    if jobid->job_status() ==# 'run'
        if how == null_string
            jobid->job_stop()
        else
            jobid->job_stop(how)
        endif
    endif
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

vim9script

import autoload '../cmd.vim'

var jobid = {}
var allitems = {}

export def Completor(cmdstr: string, shellprefix: string = null_string, max_items: number = 1000, async: bool = true): list<any>
    var winid = win_getid()
    allitems[winid] = []
    var items = allitems[winid]
    var cmdparts: any
    cmdparts = shellprefix == null_string ? cmdstr : shellprefix->split() + [cmdstr]
    if !async
        items = systemlist(cmdstr)
    else
        Stop('kill')
        var start = reltime()
        jobid[win_getid()] = job_start(cmdparts, {
            out_cb: (ch, str) => { # Invoked when channel reads a line
                items->add(str)
                if start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
                    if cmd.pmenu.Hidden()
                        Stop()
                    endif
                    ProcessItems(items, max_items)
                    start = reltime()
                endif
            },
            close_cb: (ch) => { # Invoked when no more output is available
                ProcessItems(items, max_items)
            },
            err_cb: (chan: channel, msg: string) => {
                # Do not print error here since it will stop the job.
                # 'find' can throw 'Operation not permitted' error.
                # Can use '2>/dev/null' with 'find' but need ['sh', '-c', cmd] to handle '2>'.
                # :echoerr $'error: {msg}'
                },
        })
    endif
    return items
enddef

export def Items(): list<any>
    return allitems->get(win_getid(), [])
enddef

def ProcessItems(items: list<any>, max_items: number)
    if cmd.pmenu.Closed()
        Stop()
    endif
    cmd.SetPopupMenu(items)
    if items->len() > max_items
        Stop()
    endif
enddef

export def Stop(how: string = '')
    var winid = win_getid()
    if jobid->has_key(winid)
        var job = jobid[winid]
        if job->job_status() ==# 'run'
            how->empty() ? job->job_stop() : job->job_stop(how)
            jobid->remove(win_getid())
        endif
    endif
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4

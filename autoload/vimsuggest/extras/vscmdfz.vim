vim9script

# Usage:
# :VSCmdFz Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd[\ Shell_cmd_arg1\ Shell_cmd_arg2 ...] <pattern>

import autoload '../cmd.vim'

export var MAX_MENU_ITEMS = 1000
export var async = true
export var shellprefix = null_string
var items = []
var job: job

command! -nargs=+ -complete=customlist,Completor VSCmdFz DoCommand(<f-args>)

def DoCommand(action: string, cmdstr: string, pat: string)
    if pat != null_string && items->index(pat) != -1
        exe $'{action} {pat}'
    elseif !items->empty()
        exe $'{action} {items[0]}'
    endif
enddef

def ProcessItems()
    if cmd.pmenu.Closed()
        Stop()
    endif
    cmd.SetPopupMenu(items)
    if items->len() > MAX_MENU_ITEMS
        Stop()
    endif
enddef

def Completor(context: string, line: string, cursorpos: number): list<any>
    # Note: 'line' arg above contains text up to cursorpos only. So use getcmdline().
    items = []
    # Split across spaces except for escaped spaces ("\ "), after removing ':vim9[cmd]'.
    var space_escaped = getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s\+', '', '')->substitute('\\ ', '', 'g')
    var parts = space_escaped->split()  # Split across spaces except for "\ "
    if parts->len() > 3
        var cmdstr = parts[2 : ]->join(' ')
        if !async
            items = systemlist(cmdstr)
        else
            Stop('kill')
            var start = reltime()
            job = job_start(shellprefix == null_string ? cmdstr : shellprefix->split() + [cmdstr], {
                out_cb: (ch, str) => { # Invoked when channel reads a line
                    items->add(str)
                    if start->reltime()->reltimefloat() * 1000 > 100 # Update menu every 100ms
                        if cmd.pmenu.Hidden()
                            Stop()
                        endif
                        ProcessItems()
                        start = reltime()
                    endif
                },
                close_cb: (ch) => { # Invoked when no more output is available
                    ProcessItems()
                },
                err_cb: (chan: channel, msg: string) => {
                    # Do not print error here since it will stop the job.
                    # 'find' can throw 'Operation not permitted' error.
                    # Can use '2>/dev/null' with 'find' but need ['sh', '-c', cmd] to handle '2>'.
                    # :echoerr $'error: {msg}'
                },
            })
        endif
    endif
    return items
enddef

def Stop(how: string = '')
    if job->job_status() ==# 'run'
        how->empty() ? job->job_stop() : job->job_stop(how)
    endif
enddef

export def Setup()
    return
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

vim9script

# Usage:
# :VSCmd Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...

import autoload '../cmd.vim'

export var MAX_MENU_ITEMS = 1000
export var async = true
export var shellprefix = null_string
var items = []
var job: job

command! -nargs=+ -complete=customlist,Completor VSCmd DoCommand(<f-args>)

def DoCommand(action: string, cmdstr: string, arg1: string, arg2: string = null_string,
        arg3: string = null_string, arg4: string = null_string, arg5: string = null_string,
        arg6: string = null_string, arg7: string = null_string, arg8: string = null_string,
        arg9: string = null_string, arg10: string = null_string, arg11: string = null_string,
        arg12: string = null_string, arg13: string = null_string, arg14: string = null_string,
        arg15: string = null_string, arg16: string = null_string, arg17: string = null_string,
        arg18: string = null_string, arg19: string = null_string, arg20: string = null_string)
    for arg in [arg20, arg19, arg18, arg17, arg16, arg15, arg14, arg13, arg12,
            arg11, arg10, arg9, arg8, arg7, arg6, arg5, arg4, arg3, arg2, arg1]
        if arg != null_string && items->index(arg) != -1
            exe $'{action} {arg}'
            return
        endif
    endfor
    if !items->empty()
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

# vim: tabstop=8 shiftwidth=4 softtabstop=4

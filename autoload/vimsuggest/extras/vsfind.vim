vim9script

# Usage:
# :VSug Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...

import autoload '../cmd.vim'
import autoload './job.vim'

command! -nargs=+ -complete=customlist,Completor VSug DoAction(<f-args>)

def DoAction(action: string, cmdstr: string, arg1: string, arg2: string = null_string,
        arg3: string = null_string, arg4: string = null_string, arg5: string = null_string,
        arg6: string = null_string, arg7: string = null_string, arg8: string = null_string,
        arg9: string = null_string, arg10: string = null_string, arg11: string = null_string,
        arg12: string = null_string, arg13: string = null_string, arg14: string = null_string,
        arg15: string = null_string, arg16: string = null_string, arg17: string = null_string,
        arg18: string = null_string, arg19: string = null_string, arg20: string = null_string)
    var args = [arg20, arg19, arg18, arg17, arg16, arg15, arg14, arg13, arg12,
            arg11, arg10, arg9, arg8, arg7, arg6, arg5, arg4, arg3, arg2, arg1]
    var idx = args->indexof("v:val != null_string")
    var items = job.Items()
    if idx != -1 && items->index(args[idx]) != -1
        exe $'{action} {args[idx]}'
    elseif !items->empty()
        exe $'{action} {items[0]}'
    endif
enddef

export def Action(action: string, cmdstr: string, arg: string)
    function(DoAction, [action] + cmdstr->split() + [arg])()
enddef

export def Completor(context: string, line: string, cursorpos: number, cmdstr: string = null_string, shellprefix: string = null_string, max_items: number = 1000, async: bool = true): list<any>
    # Note: 'line' arg above contains text up to cursorpos only. So use getcmdline().
    var space_escaped = getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s\+', '', '')->substitute('\\ ', '', 'g')
    var parts = space_escaped->split()  # Split across spaces except for "\ "
    var cstr = null_string
    if cmdstr != null_string
        cstr = $'{cmdstr} {parts[-1]}'
    elseif parts->len() > 3
        cstr = parts[2 : ]->join(' ')
    endif
    return cstr != null_string ? job.Completor(cstr, shellprefix, max_items, async) : []
enddef

export def Setup()
    cmd.AddOnspaceHook('VSCmd')
    cmd.AddTeardownHook('VSCmd', (item) => {
        job.Stop()
    })
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

vim9script

var items = []

# :VSCmd Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd[ Shell_cmd_arg1 Shell_cmd_arg2 ...]
command! -nargs=+ -complete=customlist,Completor VSCmd DoCommand(<f-args>)

def DoCommand(action: string, cmd: string, arg1: string, arg2: string = null_string,
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

def Completor(context: string, line: string, cursorpos: number): list<any>
    items = []
    # Note: 'line' arg above contains text up to cursorpos only. So use getcmdline().
    #       Split across spaces except for escaped spaces ("\ "), after removing ':vim9[cmd]'.
    var space_escaped = getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s\+', '', '')->substitute('\\ ', '', 'g')
    var parts = space_escaped->split()  # Split across spaces except for "\ "
    if parts->len() > 3
        items = systemlist(parts[2 : ]->join(' '))
    endif
    return items
enddef

export def Setup()
    return
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4

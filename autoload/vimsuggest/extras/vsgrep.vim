vim9script

var selected_item = null_string
command! -nargs=+ -complete=customlist,Completor VSCmdI DoActionI(<f-args>)

export def DoActionI(action: string, cmdstr: string, arg1: string, arg2: string = null_string,
        arg3: string = null_string, arg4: string = null_string, arg5: string = null_string,
        arg6: string = null_string, arg7: string = null_string, arg8: string = null_string,
        arg9: string = null_string, arg10: string = null_string, arg11: string = null_string,
        arg12: string = null_string, arg13: string = null_string, arg14: string = null_string,
        arg15: string = null_string, arg16: string = null_string, arg17: string = null_string,
        arg18: string = null_string, arg19: string = null_string, arg20: string = null_string)
    if selected_item != null_string

    endif
        
    var args = [arg20, arg19, arg18, arg17, arg16, arg15, arg14, arg13, arg12,
            arg11, arg10, arg9, arg8, arg7, arg6, arg5, arg4, arg3, arg2, arg1]
    var idx = args->indexof("v:val != null_string")
    if idx != -1 && items->index(args[idx]) != -1
        exe $'{action} {args[idx]}'
    elseif !items->empty()
        exe $'{action} {items[0]}'
    endif
enddef

export def Setup()
    cmd.AddSetupHook('VSCmdI', () => {
        selected_item = null_string
        cmd.AddPostSelectHook('VSCmdI', (_) => {
            return true
        })
        cmd.AddTeardownHook('VSCmdI', (item) => {
            selected_item = item
        })
    })
    cmd.AddOnspaceHook('VSCmd')
    cmd.AddOnspaceHook('VSCmdI')
    cmd.AddTeardownHook('VSCmd', (item) => {
        job.Stop()
    })
enddef
# vim: tabstop=8 shiftwidth=4 softtabstop=4

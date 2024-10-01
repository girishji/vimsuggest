vim9script

var selected_item = null_string

command! -nargs=+ -complete=customlist,Completor VSGrep DoAction(<f-args>)

export def DoActionI(action: string, cmdstr: string, arg1: string, arg2: string = null_string,
        arg3: string = null_string, arg4: string = null_string, arg5: string = null_string,
        arg6: string = null_string, arg7: string = null_string, arg8: string = null_string,
        arg9: string = null_string, arg10: string = null_string, arg11: string = null_string,
        arg12: string = null_string, arg13: string = null_string, arg14: string = null_string,
        arg15: string = null_string, arg16: string = null_string, arg17: string = null_string,
        arg18: string = null_string, arg19: string = null_string, arg20: string = null_string)
    var text = selected
    if text == null_string
    elseif !items->empty()
        exe $'{action} {items[0]}'
    endif
    endif
    if selected != null_string
        var qfitem = getqflist({lines: [selected]}).items[0]
        if qfitem->has_key('bufnr')
            util.VisitBuffer(key, qfitem.bufnr, qfitem.lnum, qfitem.col, qfitem.vcol > 0)
            if !qfitem.bufnr->getbufvar('&buflisted')
                # getqflist keeps buffer unlisted
                setbufvar(qfitem.bufnr, '&buflisted', 1)
            endif
        endif

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
# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

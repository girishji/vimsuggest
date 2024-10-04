vim9script

# Usage:
# :<Command> Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...

import autoload '../cmd.vim'
import autoload './job.vim'

var items = []
var candidate: string

export def DoComplete(context: string, line: string, cursorpos: number,
        cmdstr: string = null_string, shellprefix: string = null_string,
        async: bool = true, timeout: number = 2000,
        max_items: number = 1000): list<any>
    echom cmd.CmdStr()
    Clear()
    # Note: 'line' arg contains text up to cursorpos only. Use the whole cmdline.
    var space_escaped = cmd.CmdStr()->substitute('\\ ', '', 'g') # Compress escaped spaces
    var parts = space_escaped->split()  # Split across spaces except for "\ "
    var cstr: string = null_string
    if cmdstr != null_string
        var suffix = cmd.CmdStr()->matchstr('\S\+\s*\zs.*$')
        if suffix != null_string
            # cstr = $'{cmdstr} "{Escape(suffix)}"'
            cstr = $'{cmdstr} "{suffix}"'
        endif
    elseif parts->len() > 3  # Ex cmd and Sh cmd entered through cmdline
        # 'expandcmd' expands '~/path', but also causes '\' to be removed, causing '\' hell.
        cstr = parts[2 : ]->mapnew((_, v) => v =~ '[~$]' ? expandcmd(v) : v)->join(' ')
        # echom 'cstr:' cstr
    endif
    if cstr != null_string
        if async
            var cmdany = shellprefix == null_string ? cstr : shellprefix->split() + [cstr]
            def ProcessItems(fpaths: list<any>)
                cmd.SetPopupMenu(fpaths)
                items = fpaths
            enddef
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shellprefix} {cstr}')
            catch  # '\' and '"' cause E282
            endtry
        endif
    endif
    SetupHooks(cmd.CmdLead())
    return items
enddef

export def DoCommand(action: string, arg1: string, arg2: string = '',
        arg3: string = '', arg4: string = '', arg5: string = '',
        arg6: string = '', arg7: string = '', arg8: string = '',
        arg9: string = '', arg10: string = '', arg11: string = '',
        arg12: string = '', arg13: string = '', arg14: string = '',
        arg15: string = '', arg16: string = '', arg17: string = '',
        arg18: string = '', arg19: string = '', arg20: string = '')
    if candidate != null_string
        :exe $'{action->substitute('\\ ', ' ', 'g')} {candidate}'
    endif
enddef

export def DoAction(arg: string = null_string, ActionFn: func(string) = null_function)
    if candidate != null_string
        var A = (ActionFn != null_function) ? ActionFn : (s) => {
            :exe $'edit {s}'
        }
        A(candidate)
    endif
    Clear()
enddef

# Extract file from grep output and edit it.
# Let quicfix parse output of 'grep' for filename, line, column.
# It deals with ':' in filename and other corner cases.
export def GrepVisitFile(line: string)
    var qfitem = getqflist({lines: [line]}).items[0]
    if qfitem->has_key('bufnr')
        VisitBuffer(qfitem.bufnr, qfitem.lnum, qfitem.col, qfitem.vcol > 0)
        if !qfitem.bufnr->getbufvar('&buflisted')
            # getqflist keeps buffer unlisted
            setbufvar(qfitem.bufnr, '&buflisted', 1)
        endif
    endif
enddef

def VisitBuffer(bufnr: number, lnum: number = -1, col: number = -1, visualcol: bool = false)
    var cmdstr = 'b'
    if lnum > 0
        if col > 0
            var pos = visualcol ? 'setcharpos' : 'setpos'
            cmdstr = $'{cmdstr} +call\ {pos}(".",\ [0,\ {lnum},\ {col},\ 0])'
        else
            cmdstr = $'{cmdstr} +{lnum}'
        endif
    endif
    :exe $":{cmdstr} {bufnr}"
enddef

export def Escape(s: string): string
    if &shellxquote == '('  # for windows, see ':h sxq'
        return s->substitute('\([' .. &shellxescape .. ']\)', '^\1', 'g')
    else
        var escaped = s->substitute('\\', '\\\\\\\', 'g')
        escaped = escaped->substitute('\[', '\\\\\\[', 'g')
        escaped = escaped->substitute('\([ "]\)', '\\\1', 'g')
        escaped = escaped->substitute('\([?()*$^.+|-]\)', '\\\\\1', 'g')
        return escaped
    endif
enddef

def SetupHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-e>, cmd 'state' object has been removed
    endif
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item) => {
        candidate = selected_item == null_string ? first_item : selected_item
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
enddef

def Clear()
    items = []
    candidate = null_string
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

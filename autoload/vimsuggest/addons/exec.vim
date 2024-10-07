vim9script

import autoload '../cmd.vim'
import autoload './job.vim'

var items: list<any>
var candidate: string

# Usage:
# :<Command> Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...
# :<Command> <pattern>
export def Complete(context: string, line: string, cursorpos: number,
        cmdstr = null_string, shellprefix = null_string,
        async = true, timeout = 2000, max_items = 1000): list<any>
    # Note: Both 'context' and 'line' arg contains text up to 'cursorpos' only.
    items = []
    candidate = null_string
    var cstr = null_string
    var shell_prefix = shellprefix
    if cmdstr != null_string
        var suffix = cmd.CmdStr()->matchstr('\S\+\s*\zs.*$')
        if suffix != null_string
            # Note: Double quoting suffix has side effects:
            # 1) User will have to escape a double quotes when typing pattern,
            # 2) Cannot specify a directory after pattern,
            # 3) ':VSLiveFind |*' will not complete through a keymap,
            # since cursor is before a <space> (can be solved through timer_start).
            # cstr = $'{cmdstr} "{suffix}"'
            cstr = $'{cmdstr} {suffix}'
        endif
    else
        var parts = cmd.CmdStr()->split()
        if parts->len() > 1
            # Note: 'expandcmd' expands '~/path', but also causes '\' to be removed.
            cstr = parts[1 : ]->mapnew((_, v) => v =~ '[~$]' ? expandcmd(v) : v)->join(' ')
            shell_prefix = expand("$SHELL") != null_string ? $'{expand("$SHELL")} -c' : ''
            # shell_prefix = '/bin/sh -c'
        endif
    endif
    if cstr != null_string
        if async
            var cmdany = shell_prefix == null_string ? cstr : shell_prefix->split() + [cstr]
            echom 'here1' cmdany
            def ProcessItems(itms: list<any>)
                cmd.SetPopupMenu(itms)
                items = itms
            enddef
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shell_prefix} {cstr}')
            catch  # '\' and '"' cause E282
            endtry
        endif
    endif
    AddHooks(cmd.CmdLead())
    return items
enddef

# Usage:
# :<Command> Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...
export def CompleteEx(context: string, line: string, cursorpos: number,
        async = true, timeout = 2000, max_items = 1000): list<any>
    var escaped_spaces_removed = cmd.CmdStr()->substitute('\\ ', '', 'g')
    var parts = escaped_spaces_removed->split()
    if parts->len() > 1
        parts->remove(1)
    endif
    return Complete(context, parts->join(' '), cursorpos, null_string,
        null_string, async, timeout, max_items)
enddef

# Usage:
# :<Command> Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...
# :<Command> <pattern>
export def DoAction(ActionFn: func(string), arg1: string = '',
        arg2: string = '', arg3: string = '', arg4: string = '',
        arg5: string = '', arg6: string = '', arg7: string = '',
        arg8: string = '', arg9: string = '', arg10: string = '',
        arg11: string = '', arg12: string = '', arg13: string = '',
        arg14: string = '', arg15: string = '', arg16: string = '',
        arg17: string = '', arg18: string = '', arg19: string = '',
        arg20: string = '')
    if candidate != null_string
        if ActionFn != null_function
            ActionFn(candidate)
        else
            DefaultAction(candidate)
        endif
    endif
enddef

# Usage:
# :<Command> Ex_cmd[\ Ex_cmd_arg1\ Ex_cmd_arg2 ...] Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...
export def DoActionEx(action: string, arg1: string = '',
        arg2: string = '', arg3: string = '', arg4: string = '',
        arg5: string = '', arg6: string = '', arg7: string = '',
        arg8: string = '', arg9: string = '', arg10: string = '',
        arg11: string = '', arg12: string = '', arg13: string = '',
        arg14: string = '', arg15: string = '', arg16: string = '',
        arg17: string = '', arg18: string = '', arg19: string = '',
        arg20: string = '')
    if candidate != null_string
        ExecAction(candidate, action->substitute('\\ ', ' ', 'g'))
    endif
enddef

export def DefaultAction(tgt: string)
    ExecAction(tgt)
enddef

export def ExecAction(tgt: string, excmd = null_string)
    if tgt->filereadable()
        :exe $'{excmd ?? "e"} {tgt}'
    else  # Assume 'tgt' is a 'grep' output line
        GrepVisitFile(excmd ?? "b", tgt)
    endif
enddef

# Extract file from grep output and edit it.
# Let quicfix parse output of 'grep' for filename, line, column. It deals with
# ':' in filename and other corner cases.
export def GrepVisitFile(excmd: string, line: string)
    var qfitem = getqflist({lines: [line]}).items[0]
    if qfitem->has_key('bufnr')
        VisitBuffer(excmd ?? 'b', qfitem.bufnr, qfitem.lnum, qfitem.col, qfitem.vcol > 0)
        if !qfitem.bufnr->getbufvar('&buflisted') # getqflist keeps buffer unlisted
            setbufvar(qfitem.bufnr, '&buflisted', 1)
        endif
    endif
enddef

def VisitBuffer(excmd: string, bufnr: number, lnum = -1, col = -1, visualcol = false)
    var cmdstr = excmd
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

def AddHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
    endif
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item) => {
        candidate = selected_item == null_string ? first_item : selected_item
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
    def MatchGrepLine(line: string, pat: string): list<any> # Match grep output
        # Remove " and ' around pattern, if any.
        var p = pat->substitute('^"', '', '')->substitute('"$', '', '')
        if p ==# pat
            p = p->substitute("^'", '', '')->substitute("'$", '', '')
        endif
        return line->matchstrpos($'.*:.\{{-}}\zs{p}')  # Remove filename, linenum, and colnum
    enddef
    cmd.AddHighlightHook(name, (suffix: string, itms: list<any>): list<any> => {
        # grep command can have a dir argument at the end. Match only what is before the cursor.
        if suffix != null_string && !itms->empty()
            return cmd.Highlight(suffix, itms,
                itms[0]->filereadable() ? null_function : MatchGrepLine)
        endif
        return [itms]
    })
    cmd.AddNoExcludeHook(name)
enddef

:defcompile

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

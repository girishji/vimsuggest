vim9script

# This Vim9 script implements non-fuzzy (regex) command-line auto-completion.
# It provides completion for shell commands, like live grep, and find
# operations, with support for asynchronous execution, as well as Ex commands.
# The script includes functions for highlighting matches, handling file visits
# from grep results, and various utility functions.

import autoload '../cmd.vim'
import autoload './job.vim'
import autoload '../keymap.vim' as km

var items: list<any>
var candidate: string
var exit_key: string
var hooks_added: dict<any>

# Generates a list of completion items based on the current command line.
# Command line should contain a shell program like 'find', 'grep' or 'ls -1'.
# External program is executed in shell command stored in `shell` option if
# `g:vimsuggest_shell` is set. Otherwise, executed directly.
# Arguments:
# - arglead: string
# - line: string
# - cursorpos: number
#     See :h command-completion-custom
# - shellprg: string
#     When provided, execute the command through shell. Example, "/bin/sh -c".
#     If 'g:vimsuggest_shell' is 'true', shell program in 'shell' option is used.
# - async: bool
#     A boolean flag indicating whether the completion should be executed asynchronously.
#     When set to true, it allows for non-blocking execution, enabling the user interface
#     to remain responsive.
# - timeout: number
#     The maximum amount of time (in milliseconds) to wait for the completion operation
#     to finish before giving up. This is particularly useful for asynchronous operations
#     where a delay might occur.
# - max_items: number
#     The maximum number of completion items to return. This limits the number of results
#     presented to the user, helping to manage performance and usability.
# Returns:
# - A list of completion items based on the provided line and arglead. If no valid
# completions are found, an empty list is returned.
# Note: Both 'arglead' and 'line' arg contains text up to 'cursorpos' only.
export def Complete(arglead: string, line: string, cursorpos: number,
        shellprg = null_string, async = true, timeout = 2000,
        max_items = 1000): list<any>
    Clear()
    # Note: Set g:vimsuggest_shell to 'true' and let shell handle '~'.
    # var parts = cmd.CmdStr()->split()
    # if parts->len() > 1
    #     # Note: 'expandcmd' expands '~/path', but removes '\'. Use it minimally.
    #     var cstr = parts[1 : ]->mapnew((_, v) => v =~ '[~$]' ? expandcmd(v) : v)->join(' ')
    #     return CompletionItems(cstr, shellprg, async, timeout, max_items)
    # endif
    var cmdstr = cmd.CmdStr()->matchstr('\S\+\s\+\zs.*')
    return cmdstr != null_string ?
        CompletionItems(cmdstr, shellprg, async, timeout, max_items) : []
enddef

# Same as Complete() above, except 'grep' shell command is obtained from
# g:vimsuggest_grepprg variable or 'grepprg' option.
export def GrepComplete(A: string, L: string, C: number, shellprg = null_string,
        async = true, timeout = 2000, max_items = 1000): list<any>
    Clear()
    var cmdstr = get(g:, 'vimsuggest_grepprg', &grepprg)
    var argstr = ArgsStr()
    var arglead = argstr->matchstr(MatchPattern())->Strip()
    if cmdstr != null_string && arglead != null_string
        var parts = cmdstr->split('$\*')
        var cstr = $'{parts[0]} {argstr}{parts->len() == 2 ? $" {parts[1]}" : ""}'
        var itemss = CompletionItems(cstr, shellprg, async, timeout, max_items)
        cmd.AddHighlightHook(cmd.CmdLead(), (_: string, itms: list<any>): list<any> => {
            cmd.DoHighlight($'\c{arglead}')
            cmd.DoHighlight('^.*:\d\+:', 'VimSuggestMute')
            return [itms]
        })
        return itemss
    endif
    return []
enddef

# Same as GrepComplete() above except 'find' shell command is obtained from
# g:vimsuggest_findprg variable.
export def FindComplete(A: string, L: string, C: number, shellprg = null_string,
        async = true, timeout = 3000, max_items = 100000): list<any>
    Clear()
    var findcmd = get(g:, 'vimsuggest_findprg', null_string)
    var argstr = ArgsStr()
    var argpat = argstr->matchstr(MatchPattern())
    var cstr = null_string
    if findcmd != null_string && argpat->Strip() != null_string
        var argdir = argstr->slice(argpat->len())
        # NOTE: Set g:vimsuggest_shell to 'true' and let shell handle '~'.
        # if argdir =~ '^\s*[~$]'
        #     argdir = argdir->expandcmd()
        # endif
        var fcmd = $'{findcmd} '->split('$\*')
        if fcmd->len() == 3
            cstr = $'{fcmd[0]} {argdir ?? "."} {fcmd[1]} {argpat} {fcmd[2]}'
        else
            cstr = $'{fcmd[0]} {argpat} {argdir} {fcmd->len() == 2 ? fcmd[1] : null_string}'
        endif
        var itemss = CompletionItems(cstr, shellprg, async, timeout, max_items)
        cmd.AddHighlightHook(cmd.CmdLead(), (_: string, itms: list<any>): list<any> => {
            cmd.DoHighlight(argpat->Strip())
            return [itms]
        })
        return itemss
    endif
    return []
enddef

# Same as above, except it executes a Ex command to obtain completion candidates.
export def CompleteExCmd(arglead: string, line: string, cursorpos: number,
        ExCmdFn: func(string): list<any>): list<any>
    Clear()
    var argstr = ArgsStr()
    if argstr != null_string
        items = ExCmdFn(argstr)
        var cmdlead = cmd.CmdLead()
        if !hooks_added->has_key(cmdlead)
            hooks_added[cmdlead] = 1
            AddHooks(cmdlead)
        endif
    endif
    return items
enddef

# Utility function used by above functions to manage shell command execution.
export def CompletionItems(cmdstr = null_string, shellprg = null_string,
        async = true, timeout = 2000, max_items = 1000): list<any>
    if cmdstr != null_string
        var shellpre = shellprg
        if shellpre == null_string && get(g:, 'vimsuggest_shell', false)
            shellpre = (&shell != "" && &shellcmdflag != "") ? $'{&shell} {&shellcmdflag}' : ''
        endif
        if async
            var cmdany = shellpre == null_string ? cmdstr : shellpre->split() + [cmdstr]
            def ProcessItems(itms: list<any>)
                cmd.SetPopupMenu(itms)
                items = itms
            enddef
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shellpre} {cmdstr}')
            catch  # '\' and '"' cause E282
            endtry
        endif
    endif
    var cmdlead = cmd.CmdLead()
    if !hooks_added->has_key(cmdlead)
        hooks_added[cmdlead] = 1
        AddHooks(cmdlead)
    endif
    return items
enddef

# Executes a specified action on a selected item.
# Arguments:
# - ActionFn: func(string, string)
#     A function to be executed on the selected item. This function takes two parameters:
#     - The selected item from the items list.
#     - A string representing the exit key (example: <CR>).
# - arg{1-20}
#     Placeholders for words typed on the command line.
# Usage:
# :<Command> Shell_cmd Shell_cmd_arg1 Shell_cmd_arg2 ...
# :<Command> <pattern>
export def DoAction(ActionFn: func(string, string), arg1: string = '',
        arg2: string = '', arg3: string = '', arg4: string = '',
        arg5: string = '', arg6: string = '', arg7: string = '',
        arg8: string = '', arg9: string = '', arg10: string = '',
        arg11: string = '', arg12: string = '', arg13: string = '',
        arg14: string = '', arg15: string = '', arg16: string = '',
        arg17: string = '', arg18: string = '', arg19: string = '',
        arg20: string = '')
    if candidate != null_string
        if ActionFn != null_function
            ActionFn(candidate, exit_key)
        else
            DefaultAction(candidate, exit_key)
        endif
    endif
enddef

# Open a given file for editing. File can be opened in a split window or a new
# tab.
#  - tgt
#      - File path or a line from the output of grep command.
#  - key
#      - A string representing the exit key (example: <CR>).
export def DefaultAction(tgt: string, key: string)
    if tgt->filereadable()
        VisitFile(key, tgt)
    else  # Assume 'tgt' is a 'grep' output line
        GrepVisitFile(key, tgt)
    endif
enddef

# Return arguments typed to a command.
export def ArgsStr(): string
    return cmd.CmdStr()->matchstr('^\s*\S\+\s\+\zs.*$')
enddef

# Pattern to match everything inside quotes including " and ' escaped as \" and '',
# and to match space escaped non-quoted text.
def MatchPattern(): string
  return '\%(^"\([^"\\]*\(\\"[^"\\]*\)*\)"\|^''\([^'']*\(''''[^'']*\)*\)''\|\%(\\ \|[^ ]\)\+\)'
enddef

# Extract file from grep output and edit it.
# Let quicfix parse output of 'grep' for filename, line, column. It deals with
# ':' in filename and other corner cases.
export def GrepVisitFile(key: string, line: string)
    var qfitem = getqflist({lines: [line]}).items[0]
    if qfitem->has_key('bufnr')
        VisitBuffer(key, qfitem.bufnr, qfitem.lnum, qfitem.col, qfitem.vcol > 0)
        if !qfitem.bufnr->getbufvar('&buflisted') # getqflist keeps buffer unlisted
            setbufvar(qfitem.bufnr, '&buflisted', 1)
        endif
    endif
enddef

export def VisitBuffer(key: string, bufnr: number, lnum = -1, col = -1, visualcol = false)
    var cmdstr = 'b'
    if km.Equal(key, 'split_open')
        cmdstr = 'sb'
    elseif km.Equal(key, 'vsplit_open')
        cmdstr = 'vert sb'
    elseif km.Equal(key, 'tab_open')
        cmdstr = 'tab sb'
    endif
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

export def VisitFile(key: string, filename: string, lnum: number = -1)
    var cmdstr = 'e'
    if km.Equal(key, 'split_open')
        cmdstr = 'split'
    elseif km.Equal(key, 'vsplit_open')
        cmdstr = 'vert split'
    elseif km.Equal(key, 'tab_open')
        cmdstr = 'tabe'
    endif
    try
        if lnum > 0
            exe $":{cmdstr} +{lnum} {filename}"
        else
            exe $":{cmdstr} {filename}"
        endif
    catch /^Vim\%((\a\+)\)\=:E325:/ # catch error E325
    endtry
enddef

def Strip(pat: string): string # Remove surrounding quotes if any
    return pat->matchstr('^[''"]\?\zs\(.\{-}\)\ze[''"]\?$')
enddef

def AddHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
    endif
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item, key) => {
        candidate = selected_item == null_string ? first_item : selected_item
        exit_key = key
    })
    cmd.AddSelectItemHook(name, (_, _) => {
        job.Stop()  # Otherwise menu updates make <tab> not advance
        return true  # Do not update cmdline with selected item
    })
    cmd.AddHighlightHook(name, (arglead: string, itms: list<any>): list<any> => {
        cmd.DoHighlight(arglead)
        return [itms]
    })
enddef

export def Clear()
    items = []
    candidate = null_string
    exit_key = null_string
enddef

cmd.AddCmdlineEnterHook(() => {
    hooks_added = {}
})

:defcompile

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

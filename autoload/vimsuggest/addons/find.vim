vim9script

# Usage:
#   <Command> <pattern1> <pattern2> <pattern3>
#   When <pattern1> does not show expected result, start typing <pattern2> with
#   better heuristics. No need to erase <pattern1>. Same applies to <pattern3>.

import autoload '../cmd.vim'
import autoload './job.vim'

var items = []
var matches = [[], [], []]
var candidate = null_string
var cmdname = null_string

export def DoComplete(arglead: string, cmdline: string, cursorpos: number,
        cmdstr: string, shellprefix: string = null_string,
        async: bool = true, timeout: number = 2000, max_items: number = 1000): list<any>
    if cmdname == null_string
         cmdname = cmd.CmdLead()
        if async
            def ProcessItems(fpaths: list<any>)
                items = fpaths
                cmd.SetPopupMenu(items)
            enddef
            var cmdany = shellprefix == null_string ? cmdstr : shellprefix->split() + [cmdstr]
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shellprefix} {cmdstr}')
            catch  # '\' and '"' cause E282
            endtry
            if items->empty()
                Clear()
                return []
            endif
        endif
        SetupHooks(cmdname)
    else
        if cmd.CmdLead() !=# cmdname  # When command is rewritten after <bs>
            return []
        endif
    endif
    var lastword = getcmdline()->matchstr('\S\+$')
    if lastword != null_string
        matches = lastword->FuzzyMatch()
        return matches[0]
    endif
    return items
enddef

export def DoCommand(arg1: string = null_string, arg2: string = null_string,
        arg3: string = null_string, action: string = 'edit')
    if candidate != null_string
        :exe $'{action} {candidate}'
    else
        var args = [arg3, arg2, arg1]
        var idx = args->indexof("v:val != null_string")
        if idx != 1 && items->index(args[idx]) != -1
            :exe $'{action} {args[idx]}'
        endif
    endif
    Clear()
enddef

export def OnSpace(cmdstr: string)
    cmd.AddOnSpaceHook(cmdstr)
enddef

def FuzzyMatch(pat: string): list<any>
    # Filenames that match appear before directories that match.
    var m = items->matchfuzzypos(pat, {matchseq: 1, limit: 100})
    var filtered = [[], [], []]
    for Fn in [(k, v) => m[0][v]->fnamemodify(':t') =~# $'^{pat}', (k, v) => m[0][v]->fnamemodify(':t') !~# $'^{pat}']
        for idx in range(m[0]->len())->copy()->filter(Fn)
            filtered[0]->add(m[0][idx])
            filtered[1]->add(m[1][idx])
            filtered[2]->add(m[2][idx])
        endfor
    endfor
    filtered[1]->map((idx, v) => {
        # Char to byte index (needed by matchaddpos)
        return v->mapnew((_, c) => filtered[0][idx]->byteidx(c))
    })
    filtered[2]->map((_, _) => 1)
    return filtered
enddef

def SetupHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-e>, cmd 'state' object has been removed
    endif
    cmd.AddHighlightHook(name, (suffix: string, _: list<any>): list<any> => {
        return suffix != null_string && !matches[0]->empty() ?
            matches : [items]
    })
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item) => {
        candidate = selected_item == null_string ? first_item : selected_item
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
    cmd.AddNoExcludeHook(name)
enddef

def Clear()
    items = []
    matches = [[], [], []]
    candidate = null_string
    cmdname = null_string
enddef

cmd.AddCmdlineAbortHook(() => {
    Clear()
})

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

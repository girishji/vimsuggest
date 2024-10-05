vim9script

import autoload '../cmd.vim'
import autoload './job.vim'

var items = []
var matches = [[], [], []]
var candidate = null_string
var cmdname = null_string

export def Find(_: string, cmdline: string, cursorpos: number,
        GetItems: func(): list<any> = null_function,
        GetText: func(dict<any>): string = null_function,
        FuzzyMatcher: func(list<any>, string): list<any> = null_function): list<any>
    if cmdname == null_string
        Clear()
        cmdname = cmd.CmdLead()
        items = GetItems()
        if items->empty()
            Clear()
            return []
        endif
        SetupHooks(cmdname)
    else
        if cmd.CmdLead() !=# cmdname  # When command is rewritten after <bs>
            return []
        endif
    endif
    var text_items = (items[0]->type() == v:t_dict) ?
        items->mapnew((_, v) => GetText(v)) : items
    var lastword = getcmdline()->matchstr('\S\+$')
    if lastword != null_string
        matches = FuzzyMatcher != null_function ? items->FuzzyMatcher(lastword) :
            text_items->matchfuzzypos(lastword, {matchseq: 1, limit: 100})
        matches[1]->map((idx, v) => {
            # Char to byte index (needed by matchaddpos)
            return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
        })
        matches[2]->map((_, _) => 1)
        return matches[0]
    endif
    return text_items
enddef

export def FindFiles(arglead: string, cmdline: string, cursorpos: number,
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
        SetupHooksFindFiles(cmdname)
    else
        if cmd.CmdLead() !=# cmdname  # When command is rewritten after <bs>
            return []
        endif
    endif
    var lastword = getcmdline()->matchstr('\S\+$')
    if lastword != null_string
        matches = lastword->FuzzyMatchFiles()
        return matches[0]
    endif
    return items
enddef

export def DoAction(arglead: string = null_string, DoAction: func(any) = null_function,
        GetText: func(dict<any>): string = null_function)
    for str in [candidate, arglead] # After <c-s>, wildmenu can select an item in 'arglead'
        if str != null_string
            var isdict = (!items->empty() && items[0]->type() == v:t_dict)
            var idx = isdict ? items->indexof((_, v) => GetText(v) == str) : items->index(str)
            if idx != -1
                DoAction(items[idx])
                break
            endif
        endif
    endfor
    Clear()
enddef

export def DoFileAction(action: string, arg1: string = null_string, arg2: string = null_string,
        arg3: string = null_string)
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

def SetupHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
    endif
    cmd.AddHighlightHook(name, (suffix: string, _: list<any>): list<any> => {
        return suffix != null_string && !matches[0]->empty() ?
            matches : items
    })
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item) => {
        candidate = selected_item == null_string ? first_item : selected_item
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
enddef

def SetupHooksFindFiles(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
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

export def OnSpace(cmdstr: string)
    cmd.AddOnSpaceHook(cmdstr)
enddef

def FuzzyMatchFiles(pat: string): list<any>
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

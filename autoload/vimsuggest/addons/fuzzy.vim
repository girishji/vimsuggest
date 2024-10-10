vim9script

import autoload '../cmd.vim'
import autoload './job.vim'
import autoload './exec.vim'

var items = []
var matches = [[], [], []]
var candidate = null_string
var cmdname = null_string
var prevdir = null_string
var exit_key = null_string

export def Complete(_: string, line: string, cursorpos: number,
        GetItems: func(): list<any> = null_function): list<any>
    var cname = cmd.CmdLead()
    if cmdname == null_string || cname !=# cmdname  # When command is overwritten
        Clear()
        items = GetItems()
        if items->empty()
            Clear()
            return []
        endif
        cmdname = cname
        AddHooks(cname)
    endif
    var text_items = (items[0]->type() == v:t_dict) ?
        items->mapnew((_, v) => v.text) : items
    var lastword = getcmdline()->matchstr('\S\+$')
    if lastword != null_string
        matches = text_items->matchfuzzypos(lastword, {matchseq: 1, limit: 100})
        matches[1]->map((idx, v) => {
            # Char to byte index (needed by matchaddpos)
            return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
        })
        matches[2]->map((_, _) => 1)
        return matches[0]
    endif
    return text_items
enddef

export def FindComplete(arglead: string, line: string, cursorpos: number,
        FindFn: func(string): string = null_function, shellprefix = null_string,
        async = true, timeout = 2000, max_items = 100000): list<any>
    var cname = cmd.CmdLead()
    var regenerate_items = false
    var findcmd = null_string
    var FindCmdFn = FindFn ?? FindCmd
    var dirpath = ExtractDir()
    if cmdname == null_string || cname !=# cmdname  # When a command is overwritten
        Clear()
        cmdname = cname
        prevdir = dirpath ?? '.'
        findcmd = FindCmdFn(prevdir)
        regenerate_items = true
        AddFindHooks(cmdname)
    elseif dirpath != prevdir
        prevdir = dirpath
        findcmd = FindCmdFn(dirpath ?? '.')
        regenerate_items = true
    endif
    if regenerate_items
        if async
            def ProcessItems(fpaths: list<any>)
                items = fpaths
                cmd.SetPopupMenu(items)
            enddef
            var cmdany = shellprefix == null_string ? findcmd : shellprefix->split() + [findcmd]
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shellprefix} {findcmd}')
            catch  # '\' and '"' cause E282
            endtry
            if items->empty()
                Clear()
                return []
            endif
        endif
    endif
    var pat = ExtractPattern()
    if pat != null_string
        matches = pat->FuzzyMatchFiles()
        return matches[0]
    endif
    return items
enddef

export def DoAction(arglead = null_string, ActionFn: func(any, string) = null_function)
    for str in [candidate, arglead] # After <c-s>, wildmenu can select an item in 'arglead'
        if str != null_string
            var isdict = (!items->empty() && items[0]->type() == v:t_dict)
            var idx = isdict ? items->indexof((_, v) => v.text ==# str) : items->index(str)
            if idx != -1
                ActionFn(items[idx], exit_key)
                break
            endif
        endif
    endfor
    Clear()
enddef

# Usage:
# <Command> {pattern|dir} {pattern} {pattern} {pattern}
export def DoFindAction(arg1 = null_string, arg2 = null_string,
        arg3 = null_string, arg4 = null_string)
    if candidate != null_string
        exec.VisitFile(exit_key, candidate)
    endif
    Clear()
enddef

export def OnSpace(cmdstr: string)
    cmd.AddOnSpaceHook(cmdstr)
enddef

def FindCmd(dir: string): string
    if has('win32')
        var dpath = (dir == '.') ? dir : dir->expandcmd()
        return $'powershell -command "gci {dpath} -r -n -File"'
    endif
    if dir == '.'
        return 'find . \! \( -path "*/.*" -prune \) -type f -follow'
    else
        var dpath = dir->expandcmd()
        return $'find {dpath} \! \( -path "{dpath}/.*" -prune \) -type f -follow'
    endif
enddef

export def ExtractDir(): string
    var dir = cmd.CmdStr()->matchstr('\s*\S\+\s\+\zs\%(\\ \|\S\)\+\ze\s')
    return dir->expandcmd()->isdirectory() ? dir : null_string
enddef

export def ExtractPattern(): string
    var parts = cmd.CmdStr()->split('[^\\]\s\+')
    var dir = ExtractDir()
    if (dir == null_string && parts->len() > 1) ||
            (dir != null_string && parts->len() > 2)
        return parts[-1]
    endif
    return null_string
enddef

def AddHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
    endif
    cmd.AddHighlightHook(name, (arglead: string, _: list<any>): list<any> => {
        var isdict = (!items->empty() && items[0]->type() == v:t_dict)
        return (arglead != null_string && !matches[0]->empty()) ?
            matches : (isdict ? [items->mapnew((_, v) => v.text)] : [items])
    })
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item, key) => {
        candidate = selected_item == null_string ? first_item : selected_item
        exit_key = key
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
enddef

def AddFindHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-s>, cmd 'state' object has been removed
    endif
    cmd.AddHighlightHook(name, (_: string, _: list<any>): list<any> => {
        var pat = ExtractPattern()
        return pat != null_string && !matches[0]->empty() ?
            matches : [items]
    })
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item, key) => {
        candidate = selected_item == null_string ? first_item : selected_item
        exit_key = key
    })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
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
    prevdir = null_string
    exit_key = null_string
enddef

cmd.AddCmdlineEnterHook(() => {
    Clear()
})

cmd.AddCmdlineAbortHook(() => {
    Clear()
})

:defcompile

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

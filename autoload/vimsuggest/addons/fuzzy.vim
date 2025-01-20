vim9script

# This Vim9 script provides functionality for fuzzy auto-completion. It
# processes input patterns, starts external commands or jobs to fetch potential
# matches, and manages item selection and actions. It supports asynchronous
# operations and handles hooks for various command-line events.

import autoload '../cmd.vim'
import autoload './job.vim'
import autoload './exec.vim'

var items = []
var matches = [[], [], []]
var candidate = null_string
var cmdname = null_string
var prevdir = null_string
var exit_key = null_string

# Custom completion function with fuzzy search for Vim commands.
# Arguments:
# - arglead: string
# - line: string
# - cursorpos: number
#     See :h command-completion-custom
# - GetItems: func(): list<any>
#     A function that returns a list of items for completion.
# Returns:
# - A list of completion items. If no valid completions are found, an empty list
#   is returned.
export def Complete(arglead: string, line: string, cursorpos: number,
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
        matches = text_items->matchfuzzypos(lastword, {matchseq: 1, limit: FuzzyLimit(lastword)})
        matches[1]->map((idx, v) => {
            # Char to byte index (needed by matchaddpos)
            return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
        })
        matches[2]->map((_, _) => 1)
        return matches[0]
    endif
    return text_items
enddef

# 'Find files' completion function with fuzzy search. Vim calls this function to
# obtain completion list.
# Arguments:
# - arglead: string
# - line: string
# - cursorpos: number
#     See :h command-completion-custom
# - findcmdstr: string
#     When provided, execute the command instead of one stored in
#     g:vimsuggest_fzfindprg.
# - shellprg: string
#     When provided, execute the command through shell. Example, "/bin/sh -c".
#     If 'g:vimsuggest_shell' is 'true', shell program in 'shell' option is used.
#     Shell is useful for expanding recursive globbing wildcards like '**'.
# - async: bool
#     A flag indicating whether to perform the find operation asynchronously
#     using job_start() or synchronously using system(). Defaults to 'true'.
# - timeout: number
#     The maximum time (in milliseconds) to wait for the asynchronous
#     operation before timing out. Defaults to 2000 ms.
# - max_items: number
#     The maximum number of items to return from the find operation. Defaults
#     to 100000.
# Returns:
# - A list of files.If no valid files are found, an empty list is returned.
export def FindComplete(arglead: string, line: string, cursorpos: number,
        findcmdstr = null_string, shellprg = null_string, async = true,
        timeout = 2000, max_items = 100000): list<any>
    var cname = cmd.CmdLead()
    var regenerate_items = false
    var dirpath = ExtractDir()
    var findcmd = findcmdstr
    if cmdname == null_string || cname !=# cmdname  # When a command is overwritten
        Clear()
        cmdname = cname
        prevdir = dirpath ?? null_string
        if findcmd == null_string
            findcmd = FindCmd(prevdir ?? '.')
        endif
        regenerate_items = true
        AddFindHooks(cmdname)
    elseif dirpath != prevdir
        prevdir = dirpath
        if findcmd == null_string
            findcmd = FindCmd(dirpath ?? '.')
        endif
        regenerate_items = true
    endif
    if regenerate_items
        var shellpre = shellprg
        if shellpre == null_string && get(g:, 'vimsuggest_shell', false)
            shellpre = (&shell != "" && &shellcmdflag != "") ? $'{&shell} {&shellcmdflag}' : ''
        endif
        if async
            def ProcessItems(fpaths: list<any>)
                items = fpaths
                var idx = cmd.state.pmenu.Index()
                cmd.SetPopupMenu(items)
                # If item is selected, keep it (otherwise item gets unselected)
                if idx >= 0 && idx < 10 && exec.ArgsStr() == null_string
                    for _ in range(idx + 1)
                        cmd.state.pmenu.SelectItem('j', null_function)
                    endfor
                endif
            enddef
            var cmdany = shellpre == null_string ? findcmd : shellpre->split() + [findcmd]
            job.Start(cmdany, ProcessItems, timeout, max_items)
        else
            try
                items = systemlist($'{shellpre} {findcmd}')
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

# Executes a specified action on a selected item based on type of item selected.
# Arguments:
# - arglead: string
#     Vim calls this function with a single argument, that is typed by the user.
# - ActionFn: func(any, string)
#     A function to be executed on the selected item. This function takes two parameters:
#     - The selected item from the items list (could be of any type).
#     - A string representing the exit key (example: <CR>).
#     Defaults to `null_function` if not provided.
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

# Same as DoAction() above, except to be used with 'find' command that can take
# an optional 'directory' argument.
# Usage:
# <Command> {pattern|dir} {pattern1} {pattern2} {pattern3}
# If you mistype pattern for fuzzy search, no need to erase. Just abandon it by
# typing a space and type a new pattern.
# ActionFn is called with selected item.
export def DoFindAction(ActionFn: func(string, string), arg1 = null_string,
        arg2 = null_string, arg3 = null_string, arg4 = null_string)
    if candidate != null_string
        if ActionFn != null_function
            ActionFn(exit_key, candidate)
        else
            exec.VisitFile(exit_key, candidate)
        endif
    endif
    Clear()
enddef

def FindCmd(dir: string): string
    var findcmd = get(g:, 'vimsuggest_fzfindprg', null_string)
    if findcmd != null_string
        var fcmd = $'{findcmd} '->split('$\*')
        return $'{fcmd[0]} {dir} {fcmd->len() == 2 ? fcmd[1] : null_string}'
    endif
    var dpath = dir->expandcmd()
    if has('win32')
        var wdpath = (dir == '.') ? dir : dir->expandcmd()
        return $'powershell -command "gci {wdpath} -r -n -File"'
    endif
    if dir == '.'
        return 'find . \! \( -path "*/.*" -prune \) -type f -follow'
    else
        return $'find {dpath} \! \( -path "{dpath}/.*" -prune \) -type f -follow'
    endif
enddef

export def ExtractDir(): string
    var dir = cmd.CmdStr()->matchstr('\s*\S\+\s\+\zs\%(\\ \|\S\)\+\ze\s')
    return dir->expandcmd()->isdirectory() ? dir : null_string
enddef

# Return the last word typed on the command-line that is not a directory path.
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
    cmd.AddSelectItemHook(name, (_, _) => {
        return true # Do not update cmdline with selected item
    })
enddef

def AddFindHooks(name: string)
    AddHooks(name)
    cmd.AddSelectItemHook(name, (_, _) => {
        job.Stop()  # Otherwise menu updates make <tab> not advance
        return true  # Do not update cmdline with selected item
    })
    cmd.AddHighlightHook(name, (_: string, _: list<any>): list<any> => {
        var pat = ExtractPattern()
        return pat != null_string && !matches[0]->empty() ?
            matches : [items]
    })
enddef

def FuzzyMatchFiles(pat: string): list<any>
    var m = items->matchfuzzypos(pat, {matchseq: 1, limit: FuzzyLimit(pat)})
    var filtered = [[], [], []]
    if m[0]->len() < 1000
        # Filenames that match appear before directories that match.
        for Fn in [(k, v) => m[0][v]->fnamemodify(':t') =~# $'^{pat}',
                (k, v) => m[0][v]->fnamemodify(':t') !~# $'^{pat}']
            for idx in range(m[0]->len())->copy()->filter(Fn)
                filtered[0]->add(m[0][idx])
                filtered[1]->add(m[1][idx])
                filtered[2]->add(m[2][idx])
            endfor
        endfor
    else
        filtered = m
    endif
    filtered[1]->map((idx, v) => {
        # Char to byte index (needed by matchaddpos)
        return v->mapnew((_, c) => filtered[0][idx]->byteidx(c))
    })
    filtered[2]->map((_, _) => 1)
    return filtered
enddef

def FuzzyLimit(pat: string): number
    var l = pat->len()
    if l == 1
        return 100
    elseif l == 2
        return 10000
    elseif l == 3
        return 100000
    else
        return 1000000
    endif
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

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

def Clear()
    items = []
    matches = [[], [], []]
    candidate = null_string
    cmdname = null_string
enddef

cmd.AddCmdlineAbortHook(() => {
    Clear()
})

export def DoComplete(arglead: string, cmdline: string, cursorpos: number,
        cmdstr: string, shellprefix: string = null_string,
        timeout: number = 2000, max_items: number = 1000): list<any>
    if cmdname == null_string
        cmdname = cmd.CmdLead()
        job.Start(cmdstr, shellprefix, (fpaths): list<any> => {
            items = fpaths
            cmd.SetPopupMenu([items])
        }, timeout, max_items)
        # items = GetItems()
        # if items->empty()
        #     Clear()
        #     return []
        # endif
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

#     if !fz->has_key(win_getid())
#         fz[win_getid()] = fuzzy.Fuzzy.new('VSfind')
#     endif
#     return fz[win_getid()].DoComplete(arglead, cmdline, cursorpos,
#         (): list<any> => {
#             return systemlist(cmdstr)
#         },
#         null_function,
#         (items, pat) => {
#             var m = items->matchfuzzypos(pat, {matchseq: 1, limit: 100})
#             var filtered = [[], [], []]  # Filenames that match appear first
#             for Fn in [(k, v) => m[0][v]->fnamemodify(':t') =~# $'^{pat}', (k, v) => m[0][v]->fnamemodify(':t') !~# $'^{pat}']
#                 for idx in range(m[0]->len())->copy()->filter(Fn)
#                     filtered[0]->add(m[0][idx])
#                     filtered[1]->add(m[1][idx])
#                     filtered[2]->add(m[2][idx])
#                 endfor
#             endfor
#             return filtered
#         })
# enddef

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

# export def DoCommand(arglead: string = null_string, DoAction: func(any) = null_function,
#         GetText: func(dict<any>): string = null_function)
#     # if candidate == null_string && arglead == null_string && items->empty()
#     #     return
#     # endif
#     # if candidate != null_string  # items list cannot be empty
#     #     var isdict = items[0]->type() == v:t_dict
#     #     # if isdict && GetText == null_function
#     #     #     echoerr "DoCommand: GetText function not specified"
#     #     # endif
#     # endif

# enddef

export def DoCommand(arg1: string = null_string, arg2: string = null_string,
        arg3: string = null_string, ActionFn: func(string) = null_function)
    var Action = ActionFn ?? (argstr) => {
        :exe $'e {cmdstr}'
    })
    if candidate != null_string
        Action(candidate)
    else
        var args = [arg3, arg2, arg1]
        var idx = args->indexof("v:val != null_string")
        if idx != 1 && items->index(args[idx]) != -1
            ActionFn(args[idx])
        endif
    endif
    Clear()
enddef


    #     var arglead = (idx == -1) ? null_string : args[idx]


    # for str in [candidate, arglead] # After <c-e>, wildmenu can select an item in 'arglead'
    #     if str != null_string
    #         var isdict = (!items->empty() && items[0]->type() == v:t_dict)
    #         var idx = isdict ? items->indexof((_, v) => GetText(v) == str) : items->index(str)
    #         if idx != -1
    #             DoAction(items[idx])
    #             break
    #         endif
    #     endif
    # endfor
#     fz[win_getid()].DoCommand(idx != -1 ? args[idx] : null_string, (item) => {
#     })
#     remove(fz, win_getid())
# enddef

def SetupHooks(name: string)
    if !cmd.ValidState()
        return  # After <c-e>, cmd 'state' object has been removed
    endif
    # name = name  # XXX Vim bug: cmdline-height goes +1 after the
    # # <space> when a command is typed (not keymapped).
    # # Maybe someone left a 'echo ""' in Vim code.
    cmd.AddHighlightHook(name, (suffix: string, _: list<any>): list<any> => {
        return suffix != null_string && !matches[0]->empty() ?
            matches : items
    })
    cmd.AddCmdlineLeaveHook(name, (selected_item, first_item) => {
        candidate = selected_item == null_string ? first_item : selected_item
    })
    # cmd.AddCmdlineAbortHook(() => {
    #     Clear()
    # })
    cmd.AddSelectItemHook(name, (_) => {
        return true # Do not update cmdline with selected item
    })
    cmd.AddOnspaceHook(name)
enddef


# export def Setup(cmdlead: string)
#     cmd.AddCmdlineAbortHook(cmdlead, () => {
#         remove(fz, win_getid())
#     })
# enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

vim9script

import autoload '../cmd.vim'

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

export def DoComplete(_: string, cmdline: string, cursorpos: number,
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
    # if items->empty()
    #     Clear()
    #     items = GetItems()
    #     if items->empty()
    #         return []
    #     endif
    # endif
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

export def DoCommand(arglead: string = null_string, DoAction: func(any) = null_function,
        GetText: func(dict<any>): string = null_function)
    # if candidate == null_string && arglead == null_string && items->empty()
    #     return
    # endif
    # if candidate != null_string  # items list cannot be empty
    #     var isdict = items[0]->type() == v:t_dict
    #     # if isdict && GetText == null_function
    #     #     echoerr "DoCommand: GetText function not specified"
    #     # endif
    # endif

    for str in [candidate, arglead] # After <c-e>, wildmenu can select an item in 'arglead'
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
enddef



# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

vim9script

import autoload '../cmd.vim'

class Properties
    public var candidate = null_string
    public var items = []
    public var matches = [[], [], []]
    public var cmdline_leave = true
endclass

var props: dict<Properties> = {}

export def DoComplete(arg: string, cmdline: string, cursorpos: number, GetItems: func(): list<any> = null_function, GetText: func(dict<any>): string = null_function): list<any>
    if !props->has_key(win_getid())
        props[win_getid()] = Properties.new()
    endif
    var p = props[win_getid()]
    if p.items->empty() || p.cmdline_leave
        p.items = GetItems()
        p.matches = [[], [], []]
        p.candidate = null_string
        p.cmdline_leave = false
    endif
    if p.items->empty()
        return []
    endif
    var items = (p.items[0]->type() == v:t_dict) ? p.items->mapnew((_, v) => GetText(v)) : p.items
    if arg != null_string
        p.matches = items->matchfuzzypos(arg, {matchseq: 1, limit: 100})
        p.matches[1]->map((idx, v) => {
            # Char to byte index (needed by matchaddpos)
            return v->mapnew((_, c) => p.matches[0][idx]->byteidx(c))
        })
        p.matches[2]->map((_, _) => 1)
        return p.matches[0]
    endif
    return items
enddef

export def DoCommand(DoAction: func(string, list<any>), arg: string = null_string)
    var p = props[win_getid()]
    if p.candidate == null_string && p.candidate->empty()
        return
    endif
    DoAction(p.candidate, p.items)
    remove(props, win_getid())
enddef

export def Setup(cmdname: string)
    cmd.AddHighlightHook(cmdname, (suffix: string, _: list<any>): list<any> => {
        var p = props[win_getid()]
        return suffix != null_string && !p.matches[0]->empty() ? p.matches : p.items
    })
    cmd.AddOnspaceHook(cmdname)
    cmd.AddCmdlineLeaveHook(cmdname, (selected_item, first_item) => {
        var p = props[win_getid()]
        p.candidate = selected_item == null_string ? first_item : selected_item
        p.cmdline_leave = true  # This hook is called during <c-c>, <esc>, <c-e>, not just <cr>
    })
    cmd.AddSelectItemHook(cmdname, (_) => {
        return true # Do not update cmdline with selected item
    })
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

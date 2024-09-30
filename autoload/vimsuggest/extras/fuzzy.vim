vim9script

import autoload '../cmd.vim'

export class Fuzzy
    var items = []
    var matches = [[], [], []]
    var candidate = null_string
    var cmdline_leave = true

    def DoComplete(arg: string, cmdline: string, cursorpos: number,
            GetItems: func(): list<any> = null_function,
            GetText: func(dict<any>): string = null_function): list<any>
        if this.items->empty() || this.cmdline_leave
            this.items = GetItems()
            this.matches = [[], [], []]
            this.candidate = null_string
            this.cmdline_leave = false
        endif
        if this.items->empty()
            return []
        endif
        var items = (this.items[0]->type() == v:t_dict) ?
            this.items->mapnew((_, v) => GetText(v)) : this.items
        if arg != null_string
            this.matches = items->matchfuzzypos(arg, {matchseq: 1, limit: 100})
            this.matches[1]->map((idx, v) => {
                # Char to byte index (needed by matchaddpos)
                return v->mapnew((_, c) => this.matches[0][idx]->byteidx(c))
            })
            this.matches[2]->map((_, _) => 1)
            return this.matches[0]
        endif
        return items
    enddef

    def DoCommand(arg: string = null_string, DoAction: func(any) = null_function,
            GetText: func(dict<any>): string = null_function)
        if this.candidate == null_string && this.items->empty()
            return
        endif
        var isdict = this.items[0]->type() == v:t_dict
        if isdict && GetText == null_function
            echoerr "DoCommand: GetText function not specified"
        endif
        # After <c-e>, wildmenu can select an item.
        var target = (this.candidate != null_string) ? this.candidate : arg
        if target != null_string
            var idx = GetText != null_function ?
                this.items->indexof((_, v) => GetText(v) == target) :
                this.items->index(target)
            if idx != -1
                DoAction(this.candidate != null_string ? this.items[idx] : arg)
            endif
        endif
    enddef

    def new(cmdname: string)
        cmd.AddHighlightHook(cmdname, (suffix: string, _: list<any>): list<any> => {
            return suffix != null_string && !this.matches[0]->empty() ?
                this.matches : this.items
        })
        cmd.AddCmdlineLeaveHook(cmdname, (selected_item, first_item) => {
            this.candidate = selected_item == null_string ? first_item : selected_item
            # This hook is called during <c-c>, <esc>, <c-e>, not just <cr>
            this.cmdline_leave = true
        })
        cmd.AddSelectItemHook(cmdname, (_) => {
            return true # Do not update cmdline with selected item
        })
    enddef
endclass

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

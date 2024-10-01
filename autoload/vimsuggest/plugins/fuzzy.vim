vim9script

import autoload '../cmd.vim'

export class Fuzzy
    var items = []
    var matches = [[], [], []]
    var candidate = null_string
    var cmdname = null_string

    def DoComplete(arg: string, cmdline: string, cursorpos: number,
            GetItems: func(): list<any> = null_function,
            GetText: func(dict<any>): string = null_function,
            FuzzyMatcher: func(list<any>, string): list<any> = null_function): list<any>
        if this.cmdname == null_string || this._CmdLead() !=# this.cmdname  # When command is rewritten after <bs>
            return []
        endif
        if this.items->empty()
            this._Clear()
            this.items = GetItems()
        endif
        if this.items->empty()
            return []
        endif
        var items = (this.items[0]->type() == v:t_dict) ?
            this.items->mapnew((_, v) => GetText(v)) : this.items
        if arg != null_string
            this.matches = FuzzyMatcher != null_function ? items->FuzzyMatcher(arg) :
                items->matchfuzzypos(arg, {matchseq: 1, limit: 100})
            this.matches[1]->map((idx, v) => {
                # Char to byte index (needed by matchaddpos)
                return v->mapnew((_, c) => this.matches[0][idx]->byteidx(c))
            })
            this.matches[2]->map((_, _) => 1)
            return this.matches[0]
        endif
        return items
    enddef

    def DoCommand(arglead: string = null_string, DoAction: func(any) = null_function,
            GetText: func(dict<any>): string = null_function)
        if this.candidate == null_string && arglead == null_string && this.items->empty()
            return
        endif
        var isdict = this.items[0]->type() == v:t_dict
        if isdict && GetText == null_function
            echoerr "DoCommand: GetText function not specified"
        endif
        for str in [this.candidate, arglead] # After <c-e>, wildmenu can select an item in 'arglead'
            if str != null_string
                var idx = isdict ? this.items->indexof((_, v) => GetText(v) == str) :
                    this.items->index(str)
                if idx != -1
                    DoAction(this.items[idx])
                    break
                endif
            endif
        endfor
    enddef

    def new(cmdname: string)
        this.cmdname = cmdname  # XXX Vim bug: cmdline-height goes +1 after the
                                # <space> when a command is typed (not keymapped).
                                # Maybe someone left a 'echo ""' in Vim code.
        cmd.AddHighlightHook(cmdname, (suffix: string, _: list<any>): list<any> => {
            return suffix != null_string && !this.matches[0]->empty() ?
                this.matches : this.items
        })
        cmd.AddCmdlineLeaveHook(cmdname, (selected_item, first_item) => {
            this.candidate = selected_item == null_string ? first_item : selected_item
        })
        cmd.AddCmdlineAbortHook(cmdname, () => {
            this._Clear()
        })
        cmd.AddSelectItemHook(cmdname, (_) => {
            return true # Do not update cmdline with selected item
        })
    enddef

    def _Clear()
        var items = []
        var matches = [[], [], []]
        var candidate = null_string
    enddef

    def _CmdLead(): string
        return getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s*', '', '')->matchstr('^\S\+')
    enddef

endclass

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

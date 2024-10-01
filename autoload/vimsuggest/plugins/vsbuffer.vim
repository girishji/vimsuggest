vim9script

import autoload '../cmd.vim'
import autoload './fuzzy.vim'

command! -nargs=* -complete=customlist,DoComplete VSbuffer DoCommand(<f-args>)

var fz: dict<fuzzy.Fuzzy> = {}

cmd.AddOnspaceHook('VSbuffer')

def DoComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    if !fz->has_key(win_getid())
        fz[win_getid()] = fuzzy.Fuzzy.new('VSbuffer')
        cmd.AddCmdlineAbortHook('VSbuffer', () => {
            remove(fz, win_getid())
        })
    endif
    # return ['asdf', 'ew']
    return fz[win_getid()].DoComplete(arglead, cmdline, cursorpos, function(Buffers, [false]), GetText)
enddef

def DoCommand(arglead: string = null_string)
    fz[win_getid()].DoCommand(arglead, (item) => {
        :exe $'b {item->type() == v:t_dict ? item.bufnr : item}'
    }, GetText)
    remove(fz, win_getid())
enddef

def GetText(item: dict<any>): string
    return item.text
enddef

def Buffers(list_all_buffers: bool): list<any>
    var blist = list_all_buffers ? getbufinfo({buloaded: 1}) : getbufinfo({buflisted: 1})
    var buffer_list = blist->mapnew((_, v) => {
        return {bufnr: v.bufnr,
            text: (bufname(v.bufnr) ?? $'[{v.bufnr}: No Name]'),
            lastused: v.lastused}
    })->sort((i, j) => i.lastused > j.lastused ? -1 : i.lastused == j.lastused ? 0 : 1)
    # Alternate buffer first, current buffer second.
    if buffer_list->len() > 1 && buffer_list[0].bufnr == bufnr()
        [buffer_list[0], buffer_list[1]] = [buffer_list[1], buffer_list[0]]
    endif
    return buffer_list
enddef


# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

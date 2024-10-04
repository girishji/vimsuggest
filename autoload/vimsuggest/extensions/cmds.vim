vim9script

import autoload '../cmd.vim'
import autoload './fuzzy.vim'

## Buffer Names

command! -nargs=* -complete=customlist,DoBufferComplete VSbuffer DoBufferCommand(<f-args>)

cmd.AddOnspaceHook('VSbuffer')

def DoBufferComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.DoComplete(arglead, cmdline, cursorpos, function(Buffers, [false]), GetBufferName)
enddef

def DoBufferCommand(arglead: string = null_string)
    fuzzy.DoCommand(arglead, (item) => {
        :exe $'b {item->type() == v:t_dict ? item.bufnr : item}'
    }, GetBufferName)
enddef

def GetBufferName(item: dict<any>): string
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

## MRU - Most Recently Used Files

command! -nargs=* -complete=customlist,DoMRUComplete VSmru DoMRUCommand(<f-args>)

cmd.AddOnspaceHook('VSmru')

def DoMRUComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.DoComplete(arglead, cmdline, cursorpos, MRU)
enddef

def DoMRUCommand(arglead: string = null_string)
    fuzzy.DoCommand(arglead, (item) => {
        :exe $'e {item}'
    })
enddef

def MRU(): list<any>
    var mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

##

export def Setup()
    # Do nothing, just let this script load and import plugins.
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

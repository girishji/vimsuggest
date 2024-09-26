vim9script

import autoload '../cmd.vim'

var buffers = []

export def Setup()
    cmd.RegisterSetupCallback('VimSuggestBuffer', () => {
        buffers = Buffers()
    })
enddef

command! -nargs=* -complete=customlist,Completor VimSuggestBuffer DoCommand(<f-args>)

def Buffers(list_all_buffers: bool = false): list<any>
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

def DoCommand(arg: string = null_string)
    if buffers->indexof($'v:val.text == "{arg}"') != -1
        exe $'b {arg}'
    else  # Select the first item in the menu (no need to press <tab>)
        var items = (arg == null_string) ? buffers : buffers->matchfuzzy(arg, {matchseq: 1, key: 'text'})
        if !items->empty()
            exe $"b {items[0].bufnr}"
        endif
    endif
enddef

def Completor(arg: string, cmdline: string, cursorpos: number): list<any>
    var items = (arg == null_string) ? buffers : buffers->matchfuzzy(arg, {matchseq: 1, key: 'text'})
    return items->mapnew((_, v) => v.text)
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4

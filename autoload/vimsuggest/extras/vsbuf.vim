vim9script

import autoload './fuzzy.vim'

command! -nargs=* -complete=customlist,DoComplete VSBuf DoCommand(<f-args>)

def DoComplete(arg: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.DoComplete(arg, cmdline, cursorpos, function(Buffers, [false]), GetText)
enddef

def DoCommand(arg: string = null_string)
    fuzzy.DoCommand((candidate, buffers) => {
        if candidate != null_string
            var idx = buffers->indexof((_, v) => v.text == candidate)
            if idx != -1
                exe $'b {buffers[idx].bufnr}'
            endif
        elseif buffers->indexof($'v:val.text == "{arg}"') != -1 # After <c-e>, wildmenu can select an item
            exe $'b {arg}'
        endif
    }, arg)
enddef

def GetText(item: dict<any>): string
    return item.text
enddef

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

export def Setup()
    fuzzy.Setup('VSBuf')
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

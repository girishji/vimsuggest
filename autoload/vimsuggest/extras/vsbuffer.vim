vim9script

import autoload '../cmd.vim'

export def Setup()
    cmd.AddHighlightHook('VSBuffer', (suffix: string, _: list<any>): list<any> => {
        if suffix != null_string
            var matches = Buffers()->matchfuzzypos(suffix, {matchseq: 1, key: 'text'})
            matches[0]->map((_, v) => v.text)
            matches[2]->map((_, _) => 1)
            matches[1]->map((idx, v) => {
                # Char to byte index (needed by matchaddpos)
                return v->mapnew((_, c) => matches[0][idx]->byteidx(c))
            })
            return matches
        endif
        return []
    })
    cmd.AddOnspaceHook('VSBuffer')
enddef

command! -nargs=* -complete=customlist,Completor VSBuffer DoCommand(<f-args>)

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

def Completor(arg: string, cmdline: string, cursorpos: number): list<any>
    var buffers = Buffers()
    var items = (arg == null_string) ? buffers : buffers->matchfuzzy(arg, {matchseq: 1, key: 'text'})
    return items->mapnew((_, v) => v.text)
enddef

def DoCommand(arg: string = null_string)
    var buffers = Buffers() # Always get this list fresh, user could have opened another tab/window
    if buffers->indexof($'v:val.text == "{arg}"') != -1
        exe $'b {arg}'
    else  # Select the first item in the menu (no need to press <tab>)
        var items = (arg == null_string) ? buffers : buffers->matchfuzzy(arg, {matchseq: 1, key: 'text'})
        if !items->empty()
            exe $"b {items[0].bufnr}"
        endif
    endif
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4

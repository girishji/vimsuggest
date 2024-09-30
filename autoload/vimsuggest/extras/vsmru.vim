vim9script

import autoload './fuzzy.vim'

command! -nargs=* -complete=customlist,DoComplete VSMru DoCommand(<f-args>)

var fz: dict<fuzzy.Fuzzy> = {}

def DoComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    if !fz->has_key(win_getid())
        fz[win_getid()] = fuzzy.Fuzzy.new('VSMru')
    endif
    return fz[win_getid()].DoComplete(arglead, cmdline, cursorpos, MRU)
enddef

def DoCommand(arglead: string = null_string)
    fz[win_getid()].DoCommand(arglead, (item) => {
        :exe $'e {item}'
    })
    remove(fz, win_getid())
enddef

def MRU(): list<any>
    var mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

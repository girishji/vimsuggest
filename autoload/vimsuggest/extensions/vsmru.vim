vim9script

import autoload '../cmd.vim'
import autoload './fuzzy.vim'

command! -nargs=* -complete=customlist,DoComplete VSmru DoCommand(<f-args>)

cmd.AddOnspaceHook('VSmru')

def DoComplete(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.DoComplete(arglead, cmdline, cursorpos, MRU)
enddef

def DoCommand(arglead: string = null_string)
    fuzzy.DoCommand(arglead, (item) => {
        :exe $'e {item}'
    })
enddef

def MRU(): list<any>
    var mru = v:oldfiles->copy()->filter((_, v) => filereadable(fnamemodify(v, ":p")))
    mru->map((_, v) => v->fnamemodify(':.'))
    return mru
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

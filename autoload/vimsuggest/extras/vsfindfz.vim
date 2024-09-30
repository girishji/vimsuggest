vim9script

import autoload './fuzzy.vim'

# Usage:
#   VSFindFz <pattern1> <pattern2> ... <pattern5>
#   When <pattern2> is typed it abandons <pattern1>, and so on. No need to erase
#   the pattern if it is not working, simply type space and start typing a new pattern.

command! -nargs=* -complete=customlist,DoComplete VSFindFz DoCommand(<f-args>)

export var fz: dict<fuzzy.Fuzzy> = {}

export def DoComplete(arg: string, cmdline: string, cursorpos: number,
        cmdstr: string = null_string, shellprefix: string = null_string): list<any>
    var cstr = cmdstr ?? 'find . \! \( -path "*/.*" -prune \) -type f'
    if !fz->has_key(win_getid())
        fz[win_getid()] = fuzzy.Fuzzy.new('VSFindFz')
    endif
    return fz[win_getid()].DoComplete(arg, cmdline, cursorpos,
        (): list<any> => {
            return systemlist(cstr)
        },
        null_function,
        (items, pat) => {
            var m = items->matchfuzzypos(pat, {matchseq: 1, limit: 100})
            var filtered = [[], [], []]  # Filenames that match appear first
            for Fn in [(k, v) => m[0][v]->fnamemodify(':t') =~# $'^{pat}', (k, v) => m[0][v]->fnamemodify(':t') !~# $'^{pat}']
                for idx in range(m[0]->len())->copy()->filter(Fn)
                    filtered[0]->add(m[0][idx])
                    filtered[1]->add(m[1][idx])
                    filtered[2]->add(m[2][idx])
                endfor
            endfor
            return filtered
        })
enddef

export def DoCommand(arg1: string = null_string, arg2: string = null_string,
        arg3: string = null_string, arg4: string = null_string,
        arg5: string = null_string)
    var args = [arg5, arg4, arg3, arg2, arg1]
    var idx = args->indexof("v:val != null_string")
    fz[win_getid()].DoCommand(idx != -1 ? args[idx] : null_string, (item) => {
        :exe $'e {item}'
    })
    remove(fz, win_getid())
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

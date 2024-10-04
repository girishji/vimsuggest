vim9script

import autoload '../cmd.vim'
import autoload './fuzzy.vim'
import autoload './find.vim'
import autoload './live.vim'

export def Enable()
    command! -nargs=* -complete=customlist,DoFindComplete VSFind find.DoCommand(<f-args>, 'edit')
    command! -nargs=+ -complete=customlist,DoLiveFindComplete VSLiveFind live.DoAction(<f-args>)
    command! -nargs=+ -complete=customlist,DoLiveGrepComplete VSLiveGrep live.DoAction(<f-args>)
    command! -nargs=* -complete=customlist,live.DoComplete VSLive live.DoCommand(<f-args>)
    command! -nargs=* -complete=customlist,live.DoCompleteSh VSLiveSh live.DoCommand(<f-args>)
    command! -nargs=* -complete=customlist,DoBufferComplete VSBuffer DoBufferCommand(<f-args>)
    command! -nargs=* -complete=customlist,DoMRUComplete VSMru DoMRUCommand(<f-args>)
enddef

## (Fuzzy) Find Files

cmd.AddOnSpaceHook('VSFind')
def DoFindComplete(A: string, L: string, C: number): list<any>
    return find.DoComplete(A, L, C, 'find . \! \( -path "*/.*" -prune \) -type f -follow')
enddef

## (Live) Find Files

def DoLiveFindComplete(A: string, L: string, C: number): list<any>
    return live.DoComplete(A, L, C, 'find . \! \( -path "*/.*" -prune \) -type f -follow -name')
enddef

## (Live) Grep

def DoLiveGrepComplete(A: string, L: string, C: number): list<any>
    var macos = has('macunix')
    var flags = macos ? '-REIHSins' : '-REIHins'
    var cmdstr = $'grep --color=never {flags}'
    # 'sh -c' is needed for {} shell substitution.
    return live.DoComplete(A, L, C, cmdstr .. ' --exclude="{.gitignore,.swp,.zwc,tags,./.git/*}"', 'sh -c')
enddef

## Buffers

# command! -nargs=* -complete=customlist,DoBufferComplete VSBuffer DoBufferCommand(<f-args>)
cmd.AddOnSpaceHook('VSBuffer')
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

cmd.AddOnSpaceHook('VSMru')
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

export def Disable()
    for c in ['VSFind', 'VSLiveFind', 'VSBuffer', 'VSMru']
        if exists($":{c}") == 2
            :exec $'delcommand {c}'
        endif
    endfor
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

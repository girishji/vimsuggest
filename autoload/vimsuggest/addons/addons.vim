vim9script

import autoload '../cmd.vim'
import autoload './fuzzy.vim'
import autoload './live.vim'

export def Enable()
    command! -nargs=* -complete=customlist,DoFindFiles VSFind fuzzy.DoFileAction('edit', <f-args>)
    command! -nargs=+ -complete=customlist,DoLiveFindComplete VSLiveFind live.DoCommand(live.DefaultAction, <f-args>)
    command! -nargs=+ -complete=customlist,DoLiveGrepComplete VSLiveGrep live.DoCommand(live.DefaultAction, <f-args>)
    command! -nargs=* -complete=customlist,live.DoComplete VSLive live.DoCommand(live.DefaultAction, <f-args>)
    command! -nargs=* -complete=customlist,live.DoCompleteSh VSLiveSh live.DoCommand(live.DefaultAction, <f-args>)
    command! -nargs=* -complete=customlist,FindBuffer VSBuffer DoBufferAction(<f-args>)
    command! -nargs=* -complete=customlist,FindMRU VSMru DoMRUAction(<f-args>)
enddef

## (Fuzzy) Find Files

cmd.AddOnSpaceHook('VSFind')
def DoFindFiles(A: string, L: string, C: number): list<any>
    return fuzzy.FindFiles(A, L, C, 'find . \! \( -path "*/.*" -prune \) -type f -follow')
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

cmd.AddOnSpaceHook('VSBuffer')
def FindBuffer(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Find(arglead, cmdline, cursorpos, function(Buffers, [false]), GetBufferName)
enddef
def DoBufferAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
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
def FindMRU(arglead: string, cmdline: string, cursorpos: number): list<any>
    return fuzzy.Find(arglead, cmdline, cursorpos, MRU)
enddef
def DoMRUAction(arglead: string = null_string)
    fuzzy.DoAction(arglead, (item) => {
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
    # XXX
    for c in ['VSFind', 'VSLiveFind', 'VSBuffer', 'VSMru']
        if exists($":{c}") == 2
            :exec $'delcommand {c}'
        endif
    endfor
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

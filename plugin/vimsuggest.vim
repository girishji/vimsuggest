if !has('vim9script') || v:version < 901
    " Needs Vim version 9.1 and above
    echoerr "Vim 9.1 and above needed"
    finish
endif

vim9script

g:loaded_vimsuggest = true

import autoload '../autoload/vimsuggest/search.vim'
import '../autoload/vimsuggest/addons/addons.vim'  # import this before cmd.vim so 'User' autocmds are registered
import autoload '../autoload/vimsuggest/cmd.vim'
import autoload '../autoload/vimsuggest/keymap.vim'

def! g:VimSuggestSetOptions(opts: dict<any>)
    for tgt in ['search', 'cmd', 'keymap']
        if opts->has_key(tgt)
            eval($'{tgt}.options')->extend(opts[tgt])
        endif
    endfor
    if search.options.fuzzy
        search.options.async = false
    endif
    Reset()
enddef

def VimSuggestEnable(flag: bool)
    search.options.enable = flag
    cmd.options.enable = flag
    Reset()
enddef

command! VimSuggestEnable  VimSuggestEnable(true)
command! VimSuggestDisable VimSuggestEnable(false)

def Reset()
    search.Teardown()
    search.Setup()
    cmd.Teardown()
    cmd.Setup()
enddef

autocmd VimEnter * Reset()

if empty(prop_type_get('VimSuggestMatch'))
    if !hlget('PmenuMatch')->empty()
        :highlight default link VimSuggestMatch PmenuMatch
    else
        :highlight VimSuggestMatch cterm=underline
    endif
    prop_type_add('VimSuggestMatch', {highlight: "VimSuggestMatch", override: false})
endif
:highlight default link VimSuggestMatchSel PmenuMatchSel
:highlight default link VimSuggestMute LineNr

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

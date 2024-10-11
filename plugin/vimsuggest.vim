if !has('vim9script') || v:version < 901
    " Needs Vim version 9.1 and above
    finish
endif

vim9script

g:loaded_vimsuggest = true

import autoload '../autoload/vimsuggest/search.vim'
import autoload '../autoload/vimsuggest/cmd.vim'

def! g:VimSuggestSetOptions(opts: dict<any>)
    for tgt in ['search', 'cmd']
        if opts->has_key(tgt)
            eval($'{tgt}.options')->extend(opts[tgt])
        endif
    endfor
    if search.options.fuzzy
        search.options.async = false
    endif
    Reset()
enddef

def VimSuggestgestEnable(flag: bool)
    search.options.enable = flag
    cmd.options.enable = flag
    Reset()
enddef
command! VimSuggestEnable  VimSuggestEnable(true)
command! VimSuggestDisable VimSuggestEnable(false)

if empty(prop_type_get('VimSuggestMatch'))
    :highlight default link VimSuggestMatch PmenuMatch
    prop_type_add('VimSuggestMatch', {highlight: "VimSuggestMatch", override: false})
endif
:highlight default link VimSuggestMatchSel PmenuMatchSel
:highlight default link VimSuggestMute NonText

def Reset()
    search.Teardown()
    search.Setup()
    cmd.Teardown()
    cmd.Setup()
enddef

autocmd VimEnter * Reset()

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

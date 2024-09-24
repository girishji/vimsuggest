vim9script

# Autocomplete Vimscript commands, functions, variables, help, filenames, buffers, etc.

import autoload './options.vim' as opt
import autoload './popup.vim'

var options = opt.options.cmd
var pmenu: popup.PopupMenu = null_object
var abbreviations: list<any>
var save_wildmenu: bool
var autoexclude = ["'>", '^\a/', '^\A'] # Keywords excluded from completion
var items: list<any>

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
                EnableCmdline()
                abbreviations = GetAbbrevs()
                save_wildmenu = &wildmenu
                :set nowildmenu
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if pmenu != null_object
                    pmenu.Close()
                    pmenu = null_object
                endif
                if save_wildmenu
                    :set wildmenu
                endif
            }
        augroup END
    endif
enddef

export def Teardown()
    augroup VimSuggestCmdAutocmds | autocmd!
    augroup END
enddef

def EnableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged : options.alwayson ? Complete() : TabComplete()
enddef

def DisableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged :
enddef

def TabComplete()
    var lastcharpos = getcmdpos() - 2
    if getcmdline()[lastcharpos] ==? "\<tab>"
        setcmdline(getcmdline()->slice(0, lastcharpos))
        Complete()
    endif
enddef

def GetAbbrevs(): list<any>
    var lines = execute('ca', 'silent!')
    if lines =~? gettext('No abbreviation found')
        return []
    endif
    var abb = []
    for line in lines->split("\n")
        abb->add(line->matchstr('\v^c\s+\zs\S+\ze'))
    endfor
    return abb
enddef

def Complete()
    var context = getcmdline()->strpart(0, getcmdpos() - 1)
    if context == '' || context =~ '^\s\+$'
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = getcmdline()->strpart(0, getcmdpos() - 1)
    if context !=# oldcontext
        # Likely pasted text or coming from keymap.
        return
    endif
    for pat in (options.exclude + autoexclude)
        if context =~ pat
            return
        endif
    endfor
    if context[-1] =~ '\s'
        var prompt = context->trim()
        # Ignore cmdline abbreviations and such.
        if abbreviations->index(prompt) != -1 ||
                (options.alwayson && options.onspace->index(prompt) == -1)
            pmenu.Hide()
            :redraw
            return
        endif
    endif
    var completions: list<any> = []
    if options.wildignore && context =~# '\v^(e|ed|edi|edit|f|fi|fin|find)\s+'
        # 'file_in_path' respects wildignore, 'cmdline' does not. However, it is
        # slower than wildmenu (<tab> completion).
        completions = context->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
    else
        completions = context->getcompletion('cmdline')
    endif
    if completions->len() == 0 ||
            completions->len() == 1 && context->strridx(completions[0]) != -1
            # This completion is already inserted
        return
    endif
    if !options.highlight || context[-1] =~ '\s'
        items = [completions]
    else
        var mstr = context->matchstr('\S\+$')
        echom 'mstr' mstr
        var success = true
        var cols = []
        var mlens = []
        var mlen = mstr->len()
        for text in completions
            var cnum = text->stridx(mstr)
            if cnum == -1
                success = false
                break
            endif
            cols->add([cnum])
            mlens->add(mlen)
        endfor
        echom success
        items = success ? [completions, cols, mlens] : [completions]
    endif
    echom items
    ShowPopupMenu(options.pum ? context->strridx(' ') + 2 : 1)
enddef

def ShowPopupMenu(position: number)
    pmenu.SetText(items, position)
    pmenu.Show()
    # Note: If command-line is not disabled here, it will intercept key inputs 
    # before the popup does. This prevents the popup from handling certain keys, 
    # such as <Tab> properly.
    DisableCmdline()
enddef

def PostSelectItem(index: number)
    var context = getcmdline()->strpart(0, getcmdpos() - 1)
    setcmdline(context->matchstr('^.*\s\ze') .. items[0][index])
    :redraw  # Needed for <tab> selected menu item highlighting to work
enddef

def FilterFn(winid: number, key: string): bool
    # Note: Do not include arrow keys since they are used for history lookup.
    if key == "\<Tab>" || key == "\<C-n>"
        pmenu.SelectItem('j', PostSelectItem) # Next item
    elseif key == "\<S-Tab>" || key == "\<C-p>"
        pmenu.SelectItem('k', PostSelectItem) # Prev item
    elseif key == "\<C-e>"
        pmenu.Hide()
        :redraw
        EnableCmdline()
    elseif key == "\<CR>" || key == "\<ESC>"
        return false # Let Vim process these keys further
    else
        pmenu.Hide()
        # Note: Enable command-line handling to process key inputs first.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let Vim handle process this and handle search highlighting
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        feedkeys("\<c-c>", 'n')
    endif
enddef

# Verify that this completion does not take a long time (does not hang).
var vjob: job
def Verify(context: string): bool
    if context !~ '\*\*'
        return true
    else
        if vjob->job_status() ==? 'run'
            return false
        endif
        var start = reltime()
        var cmd = ['vim', '-es', $'+:silent! call getcompletion("{context}", "cmdline") | q!']
        vjob = job_start(cmd)
        while start->reltime()->reltimefloat() * 1000 < options.timeout
            if vjob->job_status() ==? 'run'
                :sleep 10m
            else
                break
            endif
        endwhile
        if vjob->job_status() ==? 'run'
            vjob->job_stop('kill')
            # echom 'Aborted job, taking too long: ' .. context
            return false
        endif
        return true
    endif
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4

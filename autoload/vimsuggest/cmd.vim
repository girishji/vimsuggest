vim9script

# Autocomplete Vimscript commands, functions, variables, help, filenames, buffers, etc.

import autoload './options.vim' as opt
import autoload './popup.vim'
import autoload './addons/addons.vim'

var options = opt.options.cmd

class State
    var pmenu: popup.PopupMenu = null_object
    var abbreviations: list<any>
    var save_wildmenu: bool
    # Do not complete after the following characters. No worthwhile completions
    # are shown by getcompletion()
    var exclude = ['~', '!', '%', '(', ')', '+', '-', '=', '<', '>', '?', ',']
    public var items: list<any>
    # Following are the callbacks used by addons.
    public static var onspace_hook = {}
    public static var cmdline_abort_hook = []
    public var highlight_hook = {}
    public var select_item_hook = {}
    public var cmdline_leave_hook = {}
    public var noexclude_hook = {}

    def new()
        this.abbreviations = this._GetAbbrevs()
        this.save_wildmenu = &wildmenu
        :set nowildmenu
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs, options.pum)
    enddef

    def Clear()
        if this.save_wildmenu
            :set wildmenu
        endif
        this.pmenu.Close()
    enddef

    def _GetAbbrevs(): list<any>
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
endclass

export var state: State = null_object

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                state = State.new()
                EnableCmdline()
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if state != null_object # <c-e> removes this object
                    CmdlineLeaveHook(state.pmenu.SelectedItem(), state.pmenu.FirstItem())
                    state.Clear()
                    state = null_object
                endif
                # if allprops->has_key(win_getid()) # If <c-e>, props would've been removed
                #     var p = allprops[win_getid()]
                #     CmdlineLeaveHook(p.pmenu.SelectedItem(), p.pmenu.FirstItem())
                #     allprops[win_getid()].Clear()
                #     remove(allprops, win_getid())
                # endif
            }
        augroup END
        if options.addons
            addons.Enable()
        endif
    endif
enddef

export def Teardown()
    augroup VimSuggestCmdAutocmds | autocmd!
    augroup END
    if options.addons
        addons.Disable()
    endif
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

def Complete()
    var context = Context()
    if context == '' || context =~ '^\s\+$'
        :redraw  # Needed to hide popup after <bs> and cmdline is empty
                 # popup_hide() already called in FilterFn, redraw to hide the popup
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = Context()
    if context !=# oldcontext
        # Likely pasted text or coming from a keymap (if {rhs} is, say, 'nohls',
        # then this function gets called for every letter).
        return
    endif
    # Note: If <esc> is mapped to Ex cmd (say 'nohls') in normal mode, then Vim
    # calls DoComplete after CmdlineLeave (because of timer), and props will not
    # be available. Use 'state' only after 'oldcontext' above.
    if state == null_object  # Additional check
        return
    endif
    for pat in options.exclude
        if context =~ pat
            :redraw # popup_hide() already called in FilterFn, redraw to hide the popup
            return
        endif
    endfor
    var cmdstr = CmdStr()
    var cmdlead = CmdLead()
    if (!state.noexclude_hook->has_key(cmdlead) && state.exclude->index(context[-1]) != -1) ||
            state.abbreviations->index(cmdlead) != -1 ||
            (cmdstr =~ '^\s*\S\+\s\+$' && options.alwayson &&
            options.onspace->index(cmdlead) == -1 &&
            !State.onspace_hook->has_key(cmdlead))
        :redraw
        return
    endif
    var completions: list<any> = []
    if options.wildignore && cmdstr =~# '^\s*\(e\%[dit]!\?\|fin\%[d]!\?\)\s'
        # 'file_in_path' respects wildignore, 'cmdline' does not.
        # :VSCmd edit ... should not be here.
        completions = cmdstr->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
    else
        completions = context->getcompletion('cmdline')
    endif
    if completions->len() == 0 || (completions->len() == 1 && context->strridx(completions[0]) != -1)
        # No completions found, or this completion is already inserted.
        :redraw
        return
    endif
    SetPopupMenu(completions)
enddef

export def Highlight(suffix: string, itms: list<any>,
        MatchFn: func(string, string): list<any> = null_function): list<any>
    var res = [itms]
    try
        var cols = []
        var mlens = []
        for text in itms
            var [_, st, en] = MatchFn != null_function ?
                text->MatchFn(suffix) : text->matchstrpos(suffix)
            if st == -1
                break
            endif
            cols->add([st])
            mlens->add(en - st)
        endfor
        res = itms->len() == cols->len() ? [itms, cols, mlens] : [itms]
    catch  # '~' in cmdsuffix causes E33 in matchstrpos
    endtry
    return res
enddef

export def SetPopupMenu(items: list<any>)
    var context = getcmdline()
    var cmdname = CmdLead()
    var cmdsuffix = context->matchstr('\S\+$')
    if !options.highlight || context[-1] =~ '\s'
        state.items = [items]
    elseif state.highlight_hook->has_key(cmdname)
        state.items = state.highlight_hook[cmdname](cmdsuffix, items)
    else  # Add properties for syntax highlighting
        state.items = Highlight(cmdsuffix, items)
    endif
    # '&' and '$' completes Vim options and env variables respectively.
    var pos = max([' ', '&', '$']->mapnew((_, v) => context->strridx(v)))
    state.pmenu.SetText(state.items, options.pum ? pos + 2 : 1)
    if state.items[0]->len() > 0
        state.pmenu.Show()
        # Note: If command-line is not disabled here, it will intercept key inputs
        # before the popup does. This prevents the popup from handling certain keys,
        # such as <Tab> properly.
        DisableCmdline()
    endif
enddef

def SelectItemPost(index: number)
    var cmdname = CmdLead()
    if !state.select_item_hook->has_key(cmdname) || !state.select_item_hook[cmdname](state.items[0][index])
        var context = Context()
        setcmdline(context->matchstr('^.*\s\ze') .. state.items[0][index])
    endif
enddef

def FilterFn(winid: number, key: string): bool
    # Note: <C-n/p> send <up/down> arrow codes (:h :t_ku).
    #   Do not map these since they are used to cycle through history.
    if key ==? "\<Tab>"
        state.pmenu.SelectItem('j', SelectItemPost) # Next item
    elseif key ==? "\<S-Tab>"
        state.pmenu.SelectItem('k', SelectItemPost) # Prev item
    elseif key ==? "\<PageUp>"
        state.pmenu.PageUp()
    elseif key ==? "\<PageDown>"
        state.pmenu.PageDown()
    elseif key ==? "\<C-e>" || key ==? "\<End>" # Vim bug: <C-e> sends <End>(<80>@7, :h t_@7)) due to timer_start.
        state.pmenu.Hide()
        :redraw
        state.Clear()
        CmdlineAbortHook()
        state = null_object
        # remove(allprops, win_getid())
    elseif key ==? "\<CR>"
        return false # Let Vim process these keys further
    elseif key ==? "\<ESC>"
        CmdlineAbortHook()
        return false
    else
        state.pmenu.Hide()
        # Note: Redrawing after Hide() causes the popup to disappear after
        # <left>/<right> arrow keys are pressed. Arrow key events are not
        # captured by this function. Calling Hide() without triggering a redraw
        # ensures that EnableCmdline works properly, allowing the command line
        # to handle the keys first, and decide it popup needs to be updated.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let Vim handle process this and handle search highlighting
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        CmdlineAbortHook()
        state.Clear()
        state = null_object
        # remove(allprops, win_getid())
        feedkeys("\<c-c>", 'n')
    endif
enddef

def Context(): string
    return getcmdline()->strpart(0, getcmdpos() - 1)
enddef

export def CmdStr(): string
    return getcmdline()->substitute('\(^\|\s\)vim9\%[cmd]!\?\s*', '', '')
enddef

export def CmdLead(): string
    return CmdStr()->matchstr('^\S\+')
enddef

def CmdlineLeaveHook(selected_item: string, first_item: string)
    var cmdname = CmdLead()
    if state.cmdline_leave_hook->has_key(cmdname)
        state.cmdline_leave_hook[cmdname](selected_item, first_item)
    endif
enddef

def CmdlineAbortHook()
    for Hook in State.cmdline_abort_hook
        Hook()
    endfor
enddef

export def AddOnSpaceHook(cmd: string)
    State.onspace_hook[cmd] = 1
enddef

export def AddNoExcludeHook(cmd: string)
    state.noexclude_hook[cmd] = 1
enddef

export def AddCmdlineLeaveHook(cmd: string, Callback: func(string, string))
    state.cmdline_leave_hook[cmd] = Callback
enddef

export def AddCmdlineAbortHook(Callback: func())
    State.cmdline_abort_hook->add(Callback)
enddef

export def AddSelectItemHook(cmd: string, Callback: func(string): bool)
    state.select_item_hook[cmd] = Callback
enddef

export def AddHighlightHook(cmd: string, Callback: func(string, list<any>): list<any>)
    state.highlight_hook[cmd] = Callback
enddef

export def ValidState(): bool
    return state != null_object
enddef

export def PrintHooks()
    echom State.onspace_hook
    echom State.cmdline_abort_hook
    echom state.cmdline_leave_hook
    echom state.select_item_hook
    echom state.highlight_hook
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

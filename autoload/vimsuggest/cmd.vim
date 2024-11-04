vim9script

# This Vim9 script implements command-line auto-completion for the ':' command.
# It uses 'getcompletion()' to gather completion candidates and show them in a
# popup window.

import autoload './popup.vim'
import autoload './addons/addons.vim'
import autoload './aux.vim'

export var options: dict<any> = {
    enable: true,         # Enable/disable the completion functionality
    pum: true,            # 'true' for stacked popup menu, 'false' for flat
    exclude: [],          # List of (regex) patterns to exclude from completion
    onspace: ['colo\%[rscheme]', 'b\%[uffer]', 'sy\%[ntax]'],
                          # Complete after the space after the command
    alwayson: true,       # If 'false', press <tab> to open the popup menu manually
    popupattrs: {},       # Attributes for configuring the popup window
    wildignore: true,     # Exclude wildignore patterns during file completion
    addons: true,         # Enable additional completion addons (like fuzzy file finder)
    ctrl_np: false,       # 'true' to select menu using <C-n/p>, 'false' for history recall
    reverse: false,       # Upside-down menu
}

class State
    var pmenu: popup.PopupMenu = null_object
    var saved_wildchar: number
    var saved_ttimeout: bool
    var saved_ttimeoutlen: number
    # Following characters often do not provide meaningful completions.
    var exclude = ['~', '!', '%', '(', ')', '+', '=', '<', '>', '?', ',']
    public var items: list<list<any>> = [[]]
    public var insertion_point: number
    public var exit_key: string = null_string # Key pressed before closing the menu
    public var char_removed: bool
    public var tab_pressed = false    # <Tab> pressed when cursr is in the middle of cmdline
    # Following callbacks are used by addons.
    public static var onspace_hook = {}  # Complete after space anywhere (unlike options.onspace)
    public var highlight_hook = {}
    public var select_item_hook = {}
    public var cmdline_leave_hook = {}
    public static var cmdline_enter_hook = []
    public static var cmdline_abort_hook = []  # Cmdline contents not available when <c-c> aborted

    def new()
        this.saved_ttimeout = &ttimeout  # Needs to be set, otherwise <esc> delays when closing menu 
        this.saved_ttimeoutlen = &ttimeoutlen
        :set ttimeout ttimeoutlen=100
        this.saved_wildchar = &wildchar
        :set wildchar=<C-z>
        this.pmenu = popup.PopupMenu.new(FilterFn, CallbackFn, options.popupattrs,
            options.pum, options.reverse)
    enddef

    def Clear()
        :exec $'set wildchar={this.saved_wildchar}'
        if this.saved_ttimeout
            :set ttimeout
            &ttimeoutlen = this.saved_ttimeoutlen
        endif
        this.pmenu.Close()
    enddef
endclass

export var state: State = null_object

export def Setup()
    if options.enable
        augroup VimSuggestCmdAutocmds | autocmd!
            autocmd CmdlineEnter    :  {
                state = State.new()
                EnableCmdline()
                for Hook in State.cmdline_enter_hook
                    Hook()
                endfor
            }
            autocmd CmdlineChanged  :  options.alwayson ? Complete() : TabComplete()
            autocmd CmdlineLeave    :  {
                if state != null_object # <c-s> removes this object
                    CmdlineLeaveHook(state.pmenu.SelectedItem(),
                        state.pmenu.FirstItem(), state.exit_key)
                    state.Clear()
                    state = null_object
                endif
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
    addons.Disable()
enddef

def EnableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged : options.alwayson ? Complete() : TabComplete()
enddef

def DisableCmdline()
    autocmd! VimSuggestCmdAutocmds CmdlineChanged :
enddef

def TabPressed(): number
    var lastcharpos = getcmdpos() - 2
    var cmdline = getcmdline()
    if cmdline[lastcharpos] ==? "\<tab>"
        setcmdline(cmdline->slice(0, lastcharpos) .. cmdline->slice(lastcharpos + 1))
        # XXX setcmdpos() does not work here
        if getcmdpos() != lastcharpos + 1  # After setcmdline, cursor is at end of line
            foreach(range(lastcharpos), (_, _) => feedkeys("\<right>", 'in'))
            feedkeys("\<home>", 'in')
            return 2  # <Tab> in the middle of cmdlin
        else
            return 1  # <Tab> at end of cmdline
        endif
    endif
    return 0  # <Tab> not present
enddef

def TabComplete()
    var tab = TabPressed()
    if tab == 2
        timer_start(1, (_) => Complete())
    elseif tab == 1
        Complete()
    elseif state.items[0]->len() > 0  # popup window is showing (but set to hidden)
        Complete()
    else
        HideMenu()
    endif
enddef

def Complete()
    if state.char_removed
        state.char_removed = false
        return
    endif
    var context = Context()
    if context == '' || context =~ '^\s\+$'
        HideMenu()  # Needed to hide popup after <bs> and cmdline is empty
        return
    endif
    timer_start(1, function(DoComplete, [context]))
enddef

def HideMenu()
    :redraw # popup_hide() already called in FilterFn, redraw to hide the popup
    state.items = [[]]
enddef

def DoComplete(oldcontext: string, timer: number)
    var context = Context()
    if context !=# oldcontext
        # Likely pasted text or coming from a keymap (if {rhs} is, say, 'nohls',
        # then this function gets called for every letter).
        return
    endif
    # Note: If <esc> is mapped to Ex cmd (say 'nohls') in normal mode, then Vim
    # calls DoComplete (for 'n', 'o', 'h', etc.) after CmdlineLeave (because of
    # timer), and state will not be available. Checking 'oldcontext' catches this.
    if state == null_object  # Additional check
        return
    endif
    var tab = TabPressed()
    var nofilter = false
    if tab == 2
        state.tab_pressed = true
        timer_start(1, (_) => Complete())
    elseif tab == 1 || state.tab_pressed
        state.tab_pressed = false
        if state.items[0]->len() > 0  # popup window is showing (but set to hidden)
            return
        else
            nofilter = true
        endif
    endif
    var cmdstr = context->CmdStr()
    var cmdlead = CmdLead()
    var excl_list = (options.exclude->type() == v:t_list) ? options.exclude : [options.exclude]
    var excl_pattern_present =
        excl_list->reduce((a, v) => a || (cmdstr->match(v) != -1), false)
    var onspace_list = (options.onspace->type() == v:t_list) ? options.onspace : [options.onspace]
    var onspace_pattern_present =
        onspace_list->reduce((a, v) => a || (cmdlead->match(v) != -1), false)
    if !nofilter && options.alwayson
        if excl_pattern_present ||
                (cmdstr =~ '^\s*\S\+\s\+$' && !onspace_pattern_present &&
                !State.onspace_hook->has_key(cmdlead))
            # Note: Second space in ':VSGrep "foo "' should be completed. Spaces
            # after cursor are not relevant. (Use 'context' instead of getcmdline()).
            HideMenu()
            return
        endif
        var unfiltered = ['h\%[elp]!\?', 'ta\%[g]!\?', 'e\%[dit]!\?', 'fin\%[d]!\?', 'b\%[uffer]!\?',
            'let', 'call', 'VSGrep', 'VSFind', 'VSGitFind']
        if cmdstr !~# $'^\s*\({unfiltered->join("\\|")}\)\s' &&
                state.exclude->index(context[-1]) != -1
            HideMenu()
            return
        endif
    endif

    var completions: list<any> = []
    try
        if options.wildignore && cmdstr =~# '^\s*\(e\%[dit]!\?\|fin\%[d]!\?\)\s'
            # 'file_in_path' respects wildignore, 'cmdline' does not.
            # :VSxxx edit ... should not be here.
            completions = cmdstr->matchstr('^\S\+\s\+\zs.*')->getcompletion('file_in_path')
        else
            completions = context->getcompletion('cmdline')
        endif
    catch # Catch (for ex.) -> E1245: Cannot expand <sfile> in a Vim9 function
    endtry
    if completions->len() == 0  # :s// and :g/ completion
        completions = aux.GetCompletionSG(context)
        if completions->len() > 0 && &hlsearch && &incsearch
            # Restore 'hls' and 'incsearch' hightlight (removed when popup_show() redraws).
            var charpos = getcmdpos() - 2
            var cmdline = getcmdline()
            setcmdline(cmdline->slice(0, charpos) .. cmdline->slice(charpos + 1))
            if getcmdpos() != charpos + 1
                feedkeys("\<home>", 'n')
                foreach(range(charpos), (_, _) => feedkeys("\<right>", 'n'))
            endif
            state.char_removed = true
            feedkeys(context[-1], 'n')
        endif
    endif
    if completions->len() == 0 || (completions->len() == 1 && context->strridx(completions[0]) != -1)
        # No completions found, or this completion is already inserted.
        HideMenu()
        return
    endif
    SetPopupMenu(completions)
enddef

export def SetPopupMenu(items: list<any>)
    var context = Context()  # Popup should be next to cursor
    var cmdname = CmdLead()
    var arglead = context->matchstr('\S\+$')
    if state.highlight_hook->has_key(cmdname)
        state.items = state.highlight_hook[cmdname](arglead, items)
    else
        state.items = [items]
        if state.items[0]->len() > 0
            DoHighlight($'\c{arglead}')
        endif
    endif
    var pos = state.items[0]->len() > 0 ? InsertionPoint(state.items[0][0]) + 1 : 1
    state.insertion_point = pos - 1
    state.pmenu.SetText(state.items, options.pum ? pos : 1)
    if state.items[0]->len() > 0
        state.pmenu.Show()
        # Note: If command-line is not disabled here, it will intercept key inputs
        # before the popup does. This prevents the popup from handling certain keys,
        # such as <Tab> properly.
        DisableCmdline()
    endif
enddef

# When ':range' is present, insertion of completion text should happen at the
# end of range. Similary, :s// and :g//.
def InsertionPoint(replacement: string): number
    if aux.insertion_point != -1
        var temp = aux.insertion_point
        aux.insertion_point = -1
        return temp
    endif
    var context = Context()
    var pos = max([' ', '&', '$']->mapnew((_, v) => context->strridx(v))) + 1
    # '&' and '$' completes Vim options and env variables respectively.
    if pos == context->len()
        return pos
    endif
    var word = context->slice(pos)
    var wordlen = word->len()
    for i in range(wordlen)
        if word->slice(i) ==? replacement->slice(0, wordlen - i)
            return i + pos
        endif
    endfor
    return pos
enddef

export def SelectItemPost(index: number, dir: string)
    var cmdname = CmdLead()
    if !state.select_item_hook->has_key(cmdname) ||
            !state.select_item_hook[cmdname](state.items[0][index], dir)
        var replacement = state.items[0][index]
        var cmdline = getcmdline()
        setcmdline(cmdline->slice(0, state.insertion_point) ..
            replacement .. cmdline->slice(getcmdpos() - 1))
        var newpos = state.insertion_point + replacement->len()
        # XXX: setcmdpos() does not work here, vim put cursor at the end.
        # workaround:
        if getcmdpos() != newpos + 1
            foreach(range(newpos), (_, _) => feedkeys("\<right>", 'in'))
            feedkeys("\<home>", 'in')
        endif
    endif
    if !state.highlight_hook->has_key(cmdname)
        # Since cmdline has selected item, match highlight has no meaning.
        win_execute(state.pmenu.Winid(), "syn clear VimSuggestMatch")
    endif
enddef

def FilterFn(winid: number, key: string): bool
    # <C-n> sends :h t_kb (down arrow) and <C-p> sends t_ku (up arrow)
    if key == "\<Tab>" || ((key == "\<C-n>" || key == "\<Down>") && options.ctrl_np)
        state.pmenu.SelectItem('j', SelectItemPost) # Next item
    elseif key == "\<S-Tab>" || ((key == "\<C-p>" || key == "\<Up>") && options.ctrl_np)
        state.pmenu.SelectItem('k', SelectItemPost) # Prev item
    elseif key == "\<PageUp>" || key == "\<S-Up>"
        var cmdname = CmdLead()
        if state.select_item_hook->has_key(cmdname)  # stop async job, if any
            state.select_item_hook[cmdname](null_string, null_string)
        endif
        state.pmenu.PageUp()
    elseif key == "\<PageDown>" || key == "\<S-Down>"
        var cmdname = CmdLead()
        if state.select_item_hook->has_key(cmdname)  # stop async job, if any
            state.select_item_hook[cmdname](null_string, null_string)
        endif
        state.pmenu.PageDown()
    elseif key == "\<C-s>"  # Dismiss auto-completion
        state.pmenu.Hide()
        :redraw
        state.Clear()
        CmdlineAbortHook()
        state = null_object
    elseif key == "\<C-q>" # Add to quickfix list
        SendToQickfixList()
        state.pmenu.Close(-1)
    elseif key == "\<C-r>"  # Add to arglist
        execute($'argadd {state.items[0]->join(" ")}')
        state.pmenu.Close(-1)
    elseif key == "\<C-g>"  # Add to system clipboard ("+ register)
        setreg('+', state.items[0]->join("\n"))
        state.pmenu.Close(-1)
    elseif key == "\<C-j>" || key == "\<C-v>" || key == "\<C-t>"
        state.exit_key = key
        feedkeys("\<cr>", 'n')
    elseif key == "\<CR>"
        # Note: When <cr> simply opens the message window (ex :filt Menu hi), popup
        # lingers unless it is explicitly hidden.
        state.pmenu.Hide()
        :redraw
        return false # Let Vim process these keys further
    elseif key == "\<ESC>" || key == "\<C-[>"
        CmdlineAbortHook()
        return false
    elseif key == "\<C-d>"
    elseif aux.CursorMovementKey(key)
        return false
    else
        if state.char_removed
            state.char_removed = false
            return false
        endif
        state.pmenu.Hide()
        # Note: Redrawing after Hide() causes the popup to disappear after
        # <left>/<right> arrow keys are pressed. Arrow key events are not
        # captured by this function. Calling Hide() without triggering a redraw
        # ensures that EnableCmdline works properly, allowing the command line
        # to handle the keys first, and decide if popup needs to be updated.
        # This approach is safer as it avoids the need to manage various
        # control characters and the up/down arrow keys used for history recall.
        EnableCmdline()
        return false # Let Vim process this further
    endif
    return true
enddef

def CallbackFn(winid: number, result: any)
    if result == -1 # Popup force closed due to <c-c> or cursor mvmt
        CmdlineAbortHook()
        state.Clear()
        state = null_object
        feedkeys("\<c-c>", 'n')
    endif
enddef

def SendToQickfixList()
    var title = CmdLead()
    var what: dict<any>
    if state.items[0][0]->filereadable()  # Assume grep output
        var itms = state.items[0]->mapnew((_, v) => {
            return {filename: v, valid: 1}
        })
        what = {nr: '$', title: title, items: itms}
    else
        var test = getqflist({lines: [state.items[0][0]]})
        if test.items[0].valid
            what = {nr: '$', title: title, lines: state.items[0]}
        else
            echom 'Invalid quickfix list format'
            return
        endif
    endif
    setqflist([], ' ', what)
    if exists($'#QuickFixCmdPost#clist')
        timer_start(0, (_) => {
            :execute $'doautocmd <nomodeline> QuickFixCmdPost clist'
        })
    endif
enddef

export def DoHighlight(pattern: string, group = 'VimSuggestMatch')
    win_execute(state.pmenu.Winid(), $"syn clear {group}")
    if pattern != null_string
        try
            win_execute(state.pmenu.Winid(), $'syn match {group} ''{pattern}''')
        catch # ignore any rogue exceptions.
        endtry
    endif
enddef

def Context(): string
    return getcmdline()->strpart(0, getcmdpos() - 1)
enddef

export def CmdStr(s: string = null_string): string
    return (s ?? getcmdline())->substitute('^\s*vim9\%[cmd]!\?\s*', '', '')
enddef

export def CmdLead(): string
    return CmdStr()->matchstr('^\s*\zs\S\+\ze\s')
enddef

def CmdlineLeaveHook(selected_item: string, first_item: string, key: string)
    var cmdname = CmdLead()
    if state.cmdline_leave_hook->has_key(cmdname)
        state.cmdline_leave_hook[cmdname](selected_item, first_item, key)
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

export def AddCmdlineLeaveHook(cmd: string, Callback: func(string, string, string))
    state.cmdline_leave_hook[cmd] = Callback
enddef

export def AddCmdlineEnterHook(Callback: func())
    State.cmdline_enter_hook->add(Callback)
enddef

export def AddCmdlineAbortHook(Callback: func())
    State.cmdline_abort_hook->add(Callback)
enddef

export def AddSelectItemHook(cmd: string, Callback: func(string, string): bool)
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
    echom State.cmdline_enter_hook
    echom State.cmdline_abort_hook
    echom state.cmdline_leave_hook
    echom state.select_item_hook
    echom state.highlight_hook
enddef

# vim: tabstop=8 shiftwidth=4 softtabstop=4 expandtab

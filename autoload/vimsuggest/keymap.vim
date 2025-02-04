vim9script

export var options: dict<any> = {
    page_up: ["\<PageUp>", "\<S-Up>"],
    page_down: ["\<PageDown>", "\<S-Down>"],
    hide: "\<C-e>",     # Hide popup window
    dismiss: "\<C-s>",  # Dismiss auto-completion
    send_to_qflist: "\<C-q>",    # Add to quickfix list
    send_to_arglist: "\<C-l>",   # Add to arglist
    send_to_clipboard: "\<C-g>", # Add to system clipboard ('+' register)
    split_open: "\<C-j>",
    vsplit_open: "\<C-v>",
    tab_open: "\<C-t>",
}

export def Equal(key: string, action: string): bool
    if options->has_key(action)
        var rhs = options[action]
        var is_list = rhs->type() == v:t_list
        if (is_list && rhs->index(key) != -1) ||
                (!is_list && rhs == key)
            return true
        endif
    endif
    return false
enddef

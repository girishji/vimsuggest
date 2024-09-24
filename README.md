# VimSuggest
Autocompletion for Vim's command-line.

(video=pattern search, alwayson, border, searching defs, multiword search)
❯ video=keymaps

	While the menu is active these keys have special meanings:
	CTRL-P		- go to the previous entry
	CTRL-N		- go to the next entry
	<Left> <Right>	- select previous/next match (like CTRL-P/CTRL-N)
	<PageUp>	- select a match several entries back
	<PageDown>	- select a match several entries further
	<Up>		- in filename/menu name completion: move up into
			  parent directory or parent menu.
	<Down>		- in filename/menu name completion: move into a
			  subdirectory or submenu.
	<CR>		- in menu completion, when the cursor is just after a
			  dot: move into a submenu.
	CTRL-E		- end completion, go back to what was there before
			  selecting a match.
	CTRL-Y		- accept the currently selected match and stop
			  completion.

	If you want <Left> and <Right> to move the cursor instead of selecting
	a different match, use this: >vim
		cnoremap <Left> <Space><BS><Left>
		cnoremap <Right> <Space><BS><Right>

async: folding and highlighting
multiple highlighting when one pattern has highlighting and next one is searched

during hls
&redrawtime=2000 
	'redrawtime' specifies the maximum time spent on finding matches.

complete(range-command)

  -- The `vim.fn.getcompletion` does not return `*no*cursorline` option.
      -- cmp-cmdline corrects `no` prefix for option name.
      local is_option_name_completion = OPTION_NAME_COMPLETION_REGEX:match_str(cmdline) ~= nil

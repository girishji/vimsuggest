# VimSuggest
Autocompletion for Vim's command-line.
<div style="display: none;">

					*backtick-expansion* *`-expansion*
On Unix and a few other systems you can also use backticks for the file name
argument, for example: >
	:next `find . -name ver\\*.c -print`
	:view `ls -t *.patch  \| head -n1`
Vim will run the command in backticks using the 'shell' and use the standard
output as argument for the given Vim command (error messages from the shell
command will be discarded).


					*starstar-wildcard*
Expanding "**" is possible on Unix, Win32, macOS and a few other systems (but
it may depend on your 'shell' setting on Unix and macOS. It's known to work
correctly for zsh; for bash this requires at least bash version >= 4.X).
This allows searching a directory tree.  This goes up to 100 directories deep.
Note there are some commands where this works slightly differently, see
|file-searching|.
Example: >
	:n **/*.txt




let s=reltime()|call getcompletion('find **', 'cmdline')|echo s->reltime()->reltimestr()
1sec in vim/*


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

:{count}fin[d][!] [++opt] [+cmd] {file}

complete(range-command)

  -- The `vim.fn.getcompletion` does not return `*no*cursorline` option.
      -- cmp-cmdline corrects `no` prefix for option name.
      local is_option_name_completion = OPTION_NAME_COMPLETION_REGEX:match_str(cmdline) ~= nil
o

- boost productiviryt
  if you hate plugin this is the one you want.
you may dislike popup that covers your buffer, but you have horizontal menu
not just about saving a tab, but saving many tabs and <bs>


After selecting a list from the popup menu of `fuzzy.QuickfixHistory()` or `fuzzy.LoclistHistory()`, you can automatically open the quickfix or location-list window. Add the following autocmd group:

```vim
augroup scope-quickfix-history
    autocmd!
    autocmd QuickFixCmdPost chistory cwindow
    autocmd QuickFixCmdPost lhistory lwindow
augroup END
```
</div>

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



#
#   Note:
#     <Tab>/<S-Tab> to select the menu item. If no item is selected <CR> visits
#     the first item in the menu.

let s=reltime()|call getcompletion('find **', 'cmdline')|echo s->reltime()->reltimestr()
1sec in vim/*

- Use symbol-based navigation (:h E387 include-search). To search inside files
  for symbols (ignoring comments) use ':il /pat'. Use `<num>[<tab>` to jump to
  the <num> occurance of the symbol shown by ':il'. `[<tab>` jumps to first
  definition, just like 'gd'. 'ilist' etc. search #include'd files while
  'dlist' lists symbols defined under #define. (Note: `gd` also goes to
  definition, but it searches within the bufer and highlights all matches
  unlike `[<tab>`.). See the section at the end of this file.
- Search buffer using ':g//' or ':g//caddexpr' (cmdline add expr to quickfix).
- If you have a lot of files to edit (say log files) for some symbol, fill a
  buffer (see command below) with filenames and use `gf` to go through files
  and `<c-o>` to bounce back.
  `:enew \| :r !find . -type f -name "*.log"`

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



This script offers a powerful suite of commands for fuzzy searching and shell command execution. Key features include:

- **Fuzzy File Search** with asynchronous jobs (`VSFind`)
- **Fuzzy Searching** for buffers, MRU, keymaps, changelists, marks, and registers
- **Live Grep Search** (glob/regex) using asynchronous jobs (`VSGrep`)
- **Live File Search** (glob/regex) using asynchronous jobs (`VSFindL`)
- **In-Buffer Search** using `:global` (`VSGlobal`)
- **Include File Search** using `:ilist` (`VSInclSearch`)
- **Custom Shell Command Execution** (`VSExec`)

You can use these commands directly or map them to your preferred keys. This script can also be customized to create your own variations. Legacy script users can import using `:import` (see `:h import-legacy`).

### Usage:

1. **Fuzzy Find Files**

   Command:
   `:VSFind [dirpath] [fuzzy_pattern]`

   This runs the `find` command asynchronously to gather files for fuzzy searching. The optional first argument is the directory to search within. Hidden files and directories are excluded by default.

   Example key mappings:
   ```
   nnoremap <key> :VSFind<space>
   nnoremap <key> :VSFind ~/.vim<space>
   nnoremap <key> :VSFind $VIMRUNTIME<space>
   ```

   To customize the `find` command, use `fuzzy.FindComplete()`.

2. **Fuzzy Search for Buffers, MRU (`:h v:oldfiles`), Keymaps, Changelists, Marks, and Registers**

   Commands:
   ```
   :VSBuffer [fuzzy_pattern]
   :VSMru [fuzzy_pattern]
   :VSKeymap [fuzzy_pattern]
   :VSChangelist [fuzzy_pattern]
   :VSMark [fuzzy_pattern]
   :VSRegister [fuzzy_pattern]
   ```

   - `VSKeymap` opens the file containing the keymap when pressed.
   - `VSMark` jumps to a specific mark.
   - `VSRegister` pastes the register's content.

   Example key mappings:
   ```
   nnoremap <key> :VSBuffer<space>
   nnoremap <key> :VSMru<space>
   nnoremap <key> :VSKeymap<space>
   nnoremap <key> :VSMark<space>
   nnoremap <key> :VSRegister<space>
   ```

3. **Live Grep Search**

   Command:
   `:VSGrep {pattern} [directory]`

   Executes a `grep` command live, showing results as you type. `{pattern}` is a glob pattern, and it’s best to enclose it in quotes to handle special characters. You can also specify an optional directory.

   The grep command is taken from `g:vimsuggest_grepprg` or the `:h 'grepprg'` option. If it contains `$*`, it gets replaced by the command-line arguments.

   Example key mappings:
   ```
   nnoremap <key> :VSGrep ""<left>
   nnoremap <key> :VSGrep "<c-r>=expand('<cword>')<cr>"<left>
   ```

   **Note**: You can substitute `grep` with `rg` or `ag`. For more advanced needs, see `:VSExec`.

4. **Live File Search**

   Command:
   `:VSFindL {pattern} [directory]`

   This command runs `find` live, showing results as you type. `{pattern}` is a glob pattern that should be enclosed in quotes if it contains wildcards. The `find` command is customized via `g:vimsuggest_findprg`.

   Example key mappings:
   ```
   nnoremap <leader>ff :VSFindL "*"<left><left>
   ```

5. **Global In-Buffer Search (`:h :global`)**

   Command:
   `:VSGlobal {regex_pattern}`

   Use this for a powerful in-buffer search with Vim's regex. For example, to list all functions in a Python file and search quickly:
   ```
   nnoremap <buffer> <key> :VSGlobal \v(^\|\s)(def\|class).{-}
   ```

   You can also search specific file types by wrapping the keymaps in autocmds (see `:h :autocmd`).

6. **Search in Included Files (`:h include-search`)**

   Command:
   `:VSInclSearch {regex_pattern}`

   Similar to `VSGlobal`, but searches both the current buffer and included files. The results are gathered using the `:ilist` command.

   Example key mappings:
   ```
   nnoremap <key> :VSInclSearch<space>
   ```

7. **Execute Shell Command**

   Command:
   `:VSExec {shell_command}`

   This command runs any shell command within your `$SHELL` environment, allowing features like brace expansion and globbing. Errors are ignored.

   Example key mappings:
   ```
   nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
   nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left>
   ```

**Additional Notes**:
1. Use `<Tab>/<S-Tab>` to navigate through menu items. Pressing `<CR>` visits the first menu item if none is selected.
2. If these commands aren't sufficient, you can define your own using the examples provided in this script.
```

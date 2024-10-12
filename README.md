# VimSuggest: Supercharge Your Vim Command-Line

The ultimate auto-completion plugin that transforms your command-line experience.

## 🚀 Elevate Your Vim Productivity

- **Intelligent Command Completion**: Never struggle to remember complex commands again.
- **Context-Aware Search Suggestions**: Find what you need, faster than ever before.

## 🌟 Comprehensive Feature Set

VimSuggest goes beyond basic auto-completion, offering a suite of advanced features:

- **Asynchronous Fuzzy File Search** (`:VSFind`): Navigate your project at the speed of thought.
- **Real-Time Live Grep** (`:VSGrep`): Instantly find text across your entire codebase using glob or regex patterns.
- **Fuzzy Searching**: Quickly locate buffers (`:VSBuffer`), Most Recently Used files (`:VSMru`), keymaps (`:VSKeymap`), changelists (`:VSChangelist`), marks (`:VSMark`), and registers (`:VSRegister`).
- **Live File Search** (`:VSFindL`): Asynchronously search for files using glob or regex patterns.
- **In-Buffer Search** (`:VSGlobal`): Harness the power of Vim's `:global` command for lightning-fast buffer searches.
- **Include File Search** (`:VSInclSearch`): Comprehensive searching across included files using Vim's `:ilist` command.
- **Custom Shell Command Execution** (`:VSExec`): Run and interact with shell commands directly within Vim.

# Requirements

- Vim version 9.1 or higher

# Installation

Install this plugin via [vim-plug](https://github.com/junegunn/vim-plug).

<details><summary><b>Show instructions</b></summary>
<br>

```vim
call plug#begin()
Plug 'girishji/vimsuggest'
call plug#end()
```

Install using Vim's built-in package manager.

```bash
$ mkdir -p $HOME/.vim/pack/downloads/opt
$ cd $HOME/.vim/pack/downloads/opt
$ git clone https://github.com/girishji/vimsuggest.git
```

Add the following line to your $HOME/.vimrc file.

```vim
packadd vimsuggest
```

</details>

# Configuration Guide

VimSuggest offers extensive customization options for both command completion and search completion. Here's how you can tailor VimSuggest to your workflow:

## Command Completion Configuration

```vim
let g:VimSuggest = {}
let g:VimSuggest.cmd = {
    \ 'enable': v:true,       " Enable/disable command completion
    \ 'pum': v:true,          " Use stacked popup menu (v:false for flat)
    \ 'fuzzy': v:false,       " Enable fuzzy completion matching
    \ 'exclude': [],          " Regex patterns to exclude from completion
    \ 'onspace': [],          " Commands to complete after space (e.g., 'buffer')
    \ 'alwayson': v:true,     " Auto-open popup (v:false to open with <Tab>)
    \ 'popupattrs': {
    \   'maxHeight': 12       " Max lines in stacked menu (pum = v:true)
    \ },
    \ 'wildignore': v:true,   " Respect 'wildignore' during file completion
    \ 'addons': v:true        " Enable additional completion addons (`:VSxxx` commands)
\ }
```

## Search Completion Configuration

```vim
let g:VimSuggest.search = {
    \ 'enable': v:true,       " Enable/disable search completion
    \ 'pum': v:false,         " Use flat menu (v:true for stacked)
    \ 'fuzzy': v:false,       " Enable fuzzy completion
    \ 'alwayson': v:true,     " Auto-open popup (v:false to open with <Tab>)
    \ 'popupattrs': {
    \   'maxheight': 12       " Max height for stacked menu
    \ },
    \ 'range': 100,           " Lines to search in each batch
    \ 'timeout': 200,         " Non-async search timeout (ms)
    \ 'async': v:true,        " Use asynchronous searching
    \ 'async_timeout': 3000,  " Async search timeout (ms)
    \ 'async_minlines': 1000, " Min lines to trigger async search
    \ 'highlight': v:true     " Enable search result highlighting
\ }
```

> [!IMPORTANT]
> Remember, setting `fuzzy` to `v:true` in search options will automatically set `async` to `v:false`.

## Applying Configuration

To apply your configuration:

```vim
call g:VimSuggestSetOptions(g:VimSuggest)
```

## Global Enable/Disable

Enable or disable VimSuggest globally:

```vim
:VimSuggestEnable   " Enable VimSuggest
:VimSuggestDisable  " Disable VimSuggest
```

## Highlighting

VimSuggest uses custom highlight groups:

- `VimSuggestMatch`: Highlights matched portion of the text. Linked to `PmenuMatch` by default.
- `VimSuggestMatchSel`: Highlights matched text in the selected item of the menu. Linked to `PmenuMatchSel` by default.
- `VimSuggestMute`: Highlights passive text like line numbers in `grep` output. Linked to `NonText` by default.

## Customization

Here are some examples:

```vim
" Customize VimSuggest's appearance and behavior

let g:VimSuggest = get(g:, 'VimSuggest', {})
let g:VimSuggest.cmd = get(g:VimSuggest, 'cmd', {})

" Customize popup window appearance
let g:VimSuggest.cmd.popupattrs = {
    \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    \ 'borderhighlight': ['Normal'],
    \ 'highlight': 'Normal',
    \ 'border': [1, 1, 1, 1],
    \ 'padding': [0, 1, 0, 1]  " Add some padding for better readability
    \ }

" Exclude specific patterns from completion
let g:VimSuggest.cmd.exclude = [
    \ '^\s*\d*\s*b\%[uffer]!\?\s\+',  " Exclude :[N]b[uffer][!]
    \ '^\s*\d*\s*sb\%[uffer]!\?\s\+'  " Also exclude :[N]sb[uffer][!]
    \ ]

" Optional: Customize highlight groups
highlight VimSuggestMatch ctermfg=Green guifg=#00FF00
highlight VimSuggestMatchSel cterm=bold gui=bold ctermfg=Green guifg=#00FF00
highlight VimSuggestMute ctermfg=Gray guifg=#808080

" Apply the configuration
call g:VimSuggestSetOptions(g:VimSuggest)
```

# Key Bindings

When the popup window is open, you can use the following key mappings:

| Key | Action |
|-----|--------|
| `<PageDown>` | Scroll down one page |
| `<PageUp>` | Scroll up one page |
| `<Tab>` | Move to next item |
| `<Shift-Tab>` | Move to previous item |
| `<Esc>` or `<Ctrl-c>` | Close popup |
| `<Ctrl-s>` | Dismiss auto-completion and revert to default Vim behavior |
| `<Enter>` | Confirm selection |
| `<Ctrl-j>` | Open file selection in a split window |
| `<Ctrl-v>` | Open file selection in a vertical split |
| `<Ctrl-t>` | Open file selection in a new tab |
| `<Ctrl-q>` | Send items to the quickfix list |
| `<Ctrl-l>` | Send items (files) to the argument list |
| `<Ctrl-g>` | Copy items to system clipboard (`"+` register) |

Note: Keys used in command-line editing (`:h cmdline-editing`) remain unmodified.

> [!TIP]
> 1. If no item is selected, pressing `<Enter>` selects the first menu item.
> 2. To automatically open the quickfix list after using `<Ctrl-q>`, add the following to your `.vimrc`:
>    ```vim
>    augroup vimsuggest-qf-show
>        autocmd!
>        autocmd QuickFixCmdPost clist cwindow
>    augroup END
>    ```





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

## Key Mappings

When menu window is open the following key mappings can be used.

Mapping | Action
--------|-------
`<PageDown>` | Page down
`<PageUp>` | Page up
`<tab>/<C-n>/<Down>/<ScrollWheelDown>` | Next item
`<S-tab>/<C-p>/<Up>/<ScrollWheelUp>` | Previous item
`<Esc>/<C-c>` | Close
`<CR>` | Confirm selection
`<C-j>` | Go to file selection in a split window
`<C-v>` | Go to file selection in a vertical split
`<C-t>` | Go to file selection in a tab
`<C-q>` | Send all unfiltered items to the quickfix list (`:h quickfix.txt`)
`<C-Q>` | Send only filtered items to the quickfix list
`<C-l>` | Send all unfiltered items to the location list (`:h location-list`)
`<C-L>` | Send only filtered items to the location list
`<C-k>` | During live grep, toggle between pattern search of results and live grep.
`<C-o>` | Send filtered files to buffer list, where applicable.
`<C-g>` | Send filtered files to argument list, where applicable (`:h arglist`)

Prompt window editor key mappings align with Vim's default mappings for command-line editing.

Mapping | Action
--------|-------
`<Left>` | Cursor one character left
`<Right>` | Cursor one character right
`<C-e>/<End>` | Move cursor to the end of line
`<C-b>/<Home>` | Move cursor to the beginning of line
`<S-Left>/<C-Left>` | Cursor one WORD left
`<S-Right>/<C-Right>` | Cursor one WORD right
`<C-u>` | Delete characters between cursor and beginning of line
`<C-w>` | Delete word before the cursor
`<C-Up>/<S-Up>` | Recall history previous
`<C-Down>/<S-Down>` | Recall history next
`<C-r><C-w>` | Insert word under cursor (`<cword>`) into prompt
`<C-r><C-a>` | Insert WORD under cursor (`<cWORD>`) into prompt
`<C-r><C-l>` | Insert line under cursor into prompt
`<C-r>` {register} | Insert the contents of a numbered or named register. Between typing CTRL-R and the second character '"' will be displayed to indicate that you are expected to enter the name of a register.

To enable emacs-style editing in the prompt window, set the option `emacsKeys` to `true` as follows:

```vim
scope#popup#OptionsSet({emacsKeys: true})
```

or,

```vim
import autoload 'scope/popup.vim' as sp
sp.OptionsSet({emacsKeys: true})
```

When emacs-style editing is enabled, following keybinding take effect:

Mapping | Action
--------|-------
`<C-b>/<Left>` | Cursor one character left
`<C-f>/<Right>` | Cursor one character right
`<C-e>/<End>` | Move cursor to the end of line
`<C-a>/<Home>` | Move cursor to the beginning of line
`<A-b>/<S-Left>/<C-Left>` | Cursor one WORD left
`<A-f>/<S-Right>/<C-Right>` | Cursor one WORD right

# Requirements

- Vim version 9.1 or higher

# Configuration

The appearance of the popup window can be customized using `borderchars`,
`borderhighlight`, `highlight`, `scrollbarhighlight`, `thumbhighlight`, `maxheight`, `maxwidth`, and
other `:h popup_create-arguments`. To wrap long lines set `wrap` to `true`
(default is `false`). To configure these settings, use
`scope#popup#OptionsSet()`.

For example, to set the border of the popup window to the `Comment` highlight group:

```vim
scope#popup#OptionsSet({borderhighlight: ['Comment']})
```

or,

```vim
import autoload 'scope/popup.vim' as sp
sp.OptionsSet({borderhighlight: ['Comment']})
```

Following highlight groups modify the content of popup window:

- `ScopeMenuMatch`: Modifies characters searched so far. Default: Linked to `Special`.
- `ScopeMenuVirtualText`: Virtual text in the Grep window. Default: Linked to `Comment`.
- `ScopeMenuSubtle`: Line number, file name, and path. Default: Linked to `Comment`.
- `ScopeMenuCurrent`: Special item indicating current status (used only when relevant). Default: Linked to `Statement`.


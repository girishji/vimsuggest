# VimSuggest: Supercharge Your Vim Command-Line

Transform your Vim command-line experience with VimSuggest, the ultimate auto-completion plugin.

## 🚀 Elevate Your Vim Productivity

- **Command Completion**: Never struggle to remember complex commands again.
- **Context-Aware Search Suggestions**: Find what you need, faster than ever before.

## 🌟 Additional Features

VimSuggest goes beyond basic auto-completion, offering a suite of advanced features by leveraging Vim's native custom completion mechanism (`:h :command-completion-custom`). These features feel like a natural extension of the editor, but they can be easily disabled if desired.

- **Asynchronous Fuzzy File Search** (`:VSFind`): Effortlessly locate files across your entire project with minimal keystrokes.
- **Real-Time Live Grep** (`:VSGrep`): Instantly find text across your entire codebase using glob or regex patterns.
- **Fuzzy Search**: Quickly locate buffers (`:VSBuffer`) and search various Vim artifacts.
- **In-Buffer Search** (`:VSGlobal`): Leverage Vim's powerful `:global` command for lightning-fast buffer searches.
- **Include File Search** (`:VSInclSearch`): Seamlessly search across included files using Vim's `:ilist` command.
- **Live File Search** (`:VSFindL`): Asynchronously search for files using glob or regex patterns.
- **Custom Shell Command Execution** (`:VSExec`): Run and interact with shell commands directly within Vim.

## Requirements

- Vim version 9.1 or higher

## Installation

Install VimSuggest via [vim-plug](https://github.com/junegunn/vim-plug) or Vim's built-in package manager.

<details>
<summary><b>Show installation instructions</b></summary>

### Using vim-plug

Add the following to your `.vimrc`:

```vim
call plug#begin()
Plug 'girishji/vimsuggest'
call plug#end()
```

### Using Vim's built-in package manager

```bash
mkdir -p $HOME/.vim/pack/downloads/opt
cd $HOME/.vim/pack/downloads/opt
git clone https://github.com/girishji/vimsuggest.git
```

Then add this line to your `.vimrc` file:

```vim
packadd vimsuggest
```

</details>

## Configuration Guide

VimSuggest offers extensive customization options for both command completion and search completion. Here's how to tailor VimSuggest to your workflow:

### Command Completion Configuration

```vim
let g:VimSuggest = {}
let g:VimSuggest.cmd = {
    \ 'enable': v:true,       " Enable/disable command completion
    \ 'pum': v:true,          " Use stacked popup menu (v:false for flat)
    \ 'fuzzy': v:false,       " Enable fuzzy completion matching
    \ 'exclude': [],          " Regex patterns to exclude from completion
    \ 'onspace': [],          " Commands to complete after space (e.g., 'buffer')
    \ 'alwayson': v:true,     " Auto-open popup (v:false to open with <Tab>)
    \ 'popupattrs': {         " Passed directly to `popup_menu()`
    \   'maxHeight': 12       " Max lines in stacked menu (pum = v:true)
    \ },
    \ 'wildignore': v:true,   " Respect 'wildignore' during file completion
    \ 'addons': v:true        " Enable additional completion addons (`:VSxxx` commands)
\ }
```

### Search Completion Configuration

```vim
let g:VimSuggest.search = {
    \ 'enable': v:true,       " Enable/disable search completion
    \ 'pum': v:false,         " Use flat menu (v:true for stacked)
    \ 'fuzzy': v:false,       " Enable fuzzy completion
    \ 'alwayson': v:true,     " Auto-open popup (v:false to open with <Tab>)
    \ 'popupattrs': {         " Passed directly to `popup_menu()`
    \   'maxheight': 12       " Max height for stacked menu
    \ },
    \ 'range': 100,           " Lines to search in each batch
    \ 'timeout': 200,         " Non-async search timeout (ms)
    \ 'async': v:true,        " Use asynchronous searching
    \ 'async_timeout': 3000,  " Async search timeout (ms)
    \ 'async_minlines': 1000, " Min lines to trigger async search
\ }
```

> [!IMPORTANT]
> 1. Searching large files will not cause any lag. By default, searching is asynchronous. Even though no external jobs are used, a timer is used during searching which pauses at regular intervals to check if there are pending keys on the type-ahead buffer.
> 2. When searching across line boundaries (`\n`), search highlighting will be turned off.

### Applying Configuration

To apply your configuration:

```vim
call g:VimSuggestSetOptions(g:VimSuggest)
```

### Global Enable/Disable

Enable or disable VimSuggest globally:

```vim
:VimSuggestEnable   " Enable VimSuggest
:VimSuggestDisable  " Disable VimSuggest
```

### Highlighting

VimSuggest uses custom highlight groups:

- `VimSuggestMatch`: Highlights matched portion of the text. Linked to `PmenuMatch` by default.
- `VimSuggestMatchSel`: Highlights matched text in the selected item of the menu. Linked to `PmenuMatchSel` by default.
- `VimSuggestMute`: Highlights passive text like line numbers in `grep` output. Linked to `NonText` by default.

### Customization Examples

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

## Key Bindings

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
| `<Ctrl-q>` | Send items (grep lines or file paths) to the quickfix list |
| `<Ctrl-l>` | Send items (file paths) to the argument list |
| `<Ctrl-g>` | Copy items to system clipboard (`+` register) |

Note: Keys used in command-line editing (`:h cmdline-editing`) remain unmodified.

> [!TIP]
> 1. If no item is selected, pressing `<Enter>` selects the first menu item (works only when using VSxxx commands).
> 2. To automatically open the quickfix list after using `<Ctrl-q>`, add the following to your `.vimrc`:
>    ```vim
>    augroup vimsuggest-qf-show
>        autocmd!
>        autocmd QuickFixCmdPost clist cwindow
>    augroup END
>    ```

## Usage

When the `addons` option is set to `v:true`, the following commands become available. You can use these commands directly or map them to your preferred keys. These commands leverage native command completion (`:h :command-completion-custom`) and feel like a natural extension of the editor.

1. **Fuzzy Find Files**

   `:VSFind [dirpath] [fuzzy_pattern]`

   This runs the `find` command asynchronously to gather files for fuzzy searching. The optional first argument is the directory to search within.

   Example key mappings:

   ```vim
   nnoremap <key> :VSFind<space>
   nnoremap <key> :VSFind ~/.vim<space>
   nnoremap <key> :VSFind $VIMRUNTIME<space>
   ```

   The 'find' program can be specified through the `g:vimsuggest_fzfindprg` variable. If this variable is not defined, a default command is used (that ignores hidden files and directories). The placeholder "$*" is allowed to specify where the optional directory argument will be included. If placeholder is not specifed, directory name is included at the end. Environment variables and tilde are expanded for directory names.

   ```vim
   let g:vimsuggest_fzfindprg = 'find $* \! \( -path "*/.*" -prune \) -type f -follow'
   let g:vimsuggest_fzfindprg = 'fd --type f'
   ```

   Performance:

   Using the system's `find` program significantly outperforms Vim's `:find` command. On the Vim repository, it takes ~1 second to list all files using `:find **/*` command, while `:VSFind` takes ~30 milliseconds (30x faster). Most of the gains come from avoiding the shell's recursive glob wildcard.

2. **Fuzzy Search Buffers and Other Vim Artifacts**

   ```
   :VSBuffer [fuzzy_pattern]
   :VSMru [fuzzy_pattern]
   :VSKeymap [fuzzy_pattern]
   :VSMark [fuzzy_pattern]
   :VSRegister [fuzzy_pattern]
   :VSChangelist [fuzzy_pattern]
   ```

   - `VSKeymap` opens the file containing the keymap when pressed.
   - `VSRegister` pastes the register's content.
   - Other commands behave as expected.
   - `VSMru` lists files from `v:oldfiles`.

   Example key mapping:

   ```vim
   nnoremap <key> :VSBuffer<space>
   ```

3. **Live Grep Search**

   `:VSGrep {pattern} [directory]`

   Executes a `grep` command live, showing results as you type. `{pattern}` is given directly to `grep` command, and it's best to enclose it in quotes to handle special characters. You can also specify an optional directory.

   Example key mappings:

   ```vim
   nnoremap <key> :VSGrep ""<left>
   nnoremap <key> :VSGrep "<c-r>=expand('<cword>')<cr>"<left>
   ```

   The grep program is taken from `g:vimsuggest_grepprg` variable or the `:h 'grepprg'` option. If it contains `$*`, it gets replaced by the command-line arguments. Otherwise, arguments are appended to the end of the command.

   ```vim
   let g:vimsuggest_grepprg = 'grep -REIHins $* --exclude-dir=.git --exclude=".*"'
   let g:vimsuggest_grepprg = 'rg --vimgrep --smart-case'
   let g:vimsuggest_grepprg = 'ag --vimgrep'
   ```

4. **Live File Search**

   `:VSFindL {pattern} [directory]`

   This command runs `find` live, showing results as you type. `{pattern}` is a glob (or regex) pattern that should be enclosed in quotes if it contains wildcards. The `find` command is customized via `g:vimsuggest_findprg` (similar to `g:vimsuggest_fzfindprg`).

   Example key mapping:

   ```vim
   nnoremap <leader>ff :VSFindL "*"<left><left>
   ```

5. **In-Buffer Search (`:h :global`)**

   `:VSGlobal {regex_pattern}`

   Use this for a powerful in-buffer search with Vim's regex. For example, to list all functions in a Python file and search quickly:

   ```vim
   nnoremap <buffer> <key> :VSGlobal \v(^\|\s)(def\|class).{-}
   ```

6. **Search in Included Files (`:h include-search`)**

   `:VSInclSearch {regex_pattern}`

   Similar to `VSGlobal`, but searches for symbols (ignoring comments) in both the current buffer and included files. The results are gathered using the `:ilist` command.

   Example key mapping:

   ```vim
   nnoremap <key> :VSInclSearch<space>
   ```

7. **Execute Shell Command**

   Command:
   `:VSExec {shell_command}`

   This command runs any shell command using your `$SHELL` environment, allowing features like brace expansion and globbing. Errors are ignored. However, `:VSGrep` and `VSFindL` commands are less clunky.

   Example key mappings:

   ```vim
   nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
   nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left>
   ```

> [!TIP]
> If these commands aren't sufficient, you can define your own using the examples provided in `autoload/vimsuggest/addons/addons.vim` script. Legacy script users can import using `:import` also (see `:h import-legacy`).

## Other Plugins

For insert-mode auto-completion, try [**Vimcomplete**](https://github.com/girishji/vimcomplete).

## Contributing

Open an issue if you encounter problems. Pull requests are welcomed.

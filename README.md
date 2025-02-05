# VimSuggest: Supercharge Your Vim Command-Line

The ultimate auto-completion plugin for Vim command-line.

## 🚀 Enhance Vim Workflow

- **Command Completion**: Never struggle to remember complex commands again.
- **Search Suggestions**: Access relevant search terms with fewer keystrokes, enhancing your navigation.

## 🌟 Additional Features

VimSuggest goes beyond basic auto-completion, offering a suite of advanced features by leveraging Vim's native custom completion mechanism (`:h :command-completion-custom`). These features feel like a natural extension of the editor, but they can be easily disabled if desired.

- **Asynchronous Fuzzy File Search** (`:VSFind`): Effortlessly locate files across your entire project with minimal keystrokes.
- **Real-Time Live Grep** (`:VSGrep`): Instantly find text across your entire codebase using glob or regex patterns.
- **Fuzzy Search**: Quickly locate buffers (`:VSBuffer`) and search various Vim artifacts.
- **In-Buffer Search** (`:VSGlobal`): Leverage Vim's powerful `:global` command for lightning-fast buffer searches.
- **Include File Search** (`:VSInclSearch`): Seamlessly search across included files using Vim's `:ilist` command.
- **Live File Search** (`:VSFindL`): Asynchronously search for files using glob or regex patterns.
- **Custom Shell Command Execution** (`:VSExec`): Run and interact with shell commands directly within Vim.

Auto-completion can also be disabled by default and only triggered when the `<Tab>` key is pressed, which more closely aligns with Vim's default behavior.

---------

![Demo](https://gist.githubusercontent.com/girishji/40e35cd669626212a9691140de4bd6e7/raw/f931e4198209452a7626bc2a6f2118dd27dac1dd/vimsuggest-demo.gif)

---------

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

#### Linux

```bash
git clone https://github.com/girishji/vimsuggest.git $HOME/.vim/pack/downloads/opt/vimsuggest
```

Then add this line to your _vimrc_ file:

```vim
packadd vimsuggest
```

#### Windows

```bash
git clone https://github.com/girishji/vimsuggest.git %USERPROFILE%\vimfiles\pack\downloads\opt\vimsuggest
```

Then add this line to your _vimrc_ file:

```vim
packadd vimsuggest
```

</details>

## Configuration Guide

VimSuggest offers extensive customization options for both command completion and search completion.

### Command Completion Configuration

```vim
let s:vim_suggest = {}
let s:vim_suggest.cmd = {
    \ 'enable': v:true,
    \ 'pum': v:true,
    \ 'exclude': [],
    \ 'onspace': ['b\%[uffer]','colo\%[rscheme]'],
    \ 'alwayson': v:true,
    \ 'popupattrs': {},
    \ 'wildignore': v:true,
    \ 'addons': v:true,
    \ 'trigger': 't',
    \ 'reverse': v:false,
    \ 'prefixlen': 1,
\ }
```

| Variable Name | Default Value | Comment |
|---------------|---------------|---------|
| `enable` | `v:true` | Enable/disable command completion |
| `pum` | `v:true` | `v:true` for stacked menu, `v:false` for flat menu |
| `exclude` | `[]` | Regex patterns to exclude from completion |
| `onspace` | `['b\%[uffer]','colo\%[rscheme]']` | Commands (regex) that trigger completion after space. Use `.*` for all |
| `alwayson` | `v:true` | Auto-open popup (`v:false` to open with `<Tab>`/`<C-d>`) |
| `popupattrs` | `{}` | Arguments passed to popup_create() (`:h popup_create-arguments`) |
| `wildignore` | `v:true` | Respect 'wildignore' during file completion |
| `addons` | `v:true` | Enable addons (`:VSxxx` commands) |
| `trigger` | `t` | `'t'` enables `<Tab>`/`<S-Tab>` as trigger characters, while `'n'` enables `<C-n>`/`<C-p>` and `<Up>/<Down>`. (See note below.) |
| `reverse` | `v:false` | Reverse-sorted menu, with the most relevant item at the bottom (when `pum=v:true`) |
| `auto_first` | `v:false` | Auto-select first menu item on `<Enter>` if none chosen (Does not affect 'addons' which always use first item) |
| `prefixlen` | `1` | The minimum prefix length before the completion menu is displayed
| `complete_sg` | `v:true` | Enables word completion (from the buffer) for the `:substitute` (`:s`) and `:global` (`:g`) commands |

> [!NOTE]
> 1. The `trigger` option specifies the character used to select items in the popup menu or invoke the menu itself. When `<Tab>`/`<C-I>` is set as the trigger, it cannot be used to input tab characters while the popup is open. In this case, use `<C-V><Tab>`/`<C-V><C-I>`.
>    - These trigger options can be combined. For instance, setting `tn` allows `<Tab>`/`<S-Tab>` as well as `<C-n>`/`<C-p>` and `<Up>`/`<Down>` to navigate the menu. However, history recall using the arrow keys will only work when the command-line is empty.
> 2. If the popup menu does not appear due to a match in the `exclude` list, typing `<C-D>` will override the `exclude` list and immediately display the completion menu.
> 3. To enable fuzzy completion matching, use the command `:set wildoptions+=fuzzy`.

### Search Completion Configuration

```vim
let s:vim_suggest.search = {
    \ 'enable': v:true,
    \ 'pum': v:true,
    \ 'fuzzy': v:false,
    \ 'alwayson': v:true,
    \ 'popupattrs': {
    \   'maxheight': 12
    \ },
    \ 'range': 100,
    \ 'timeout': 200,
    \ 'async': v:true,
    \ 'async_timeout': 3000,
    \ 'async_minlines': 1000,
    \ 'highlight': v:true,
    \ 'trigger': 't',
    \ 'prefixlen': 1,
\ }
```

| Variable Name | Default Value | Comment |
|---------------|---------------|---------|
| `enable` | `v:true` | Enable/disable search completion |
| `pum` | `v:true` | `v:true` for stacked menu, `v:false` for flat menu |
| `fuzzy` | `v:false` | Enable fuzzy completion |
| `alwayson` | `v:true` | Auto-open popup (`v:false` to open with `<Tab>`/`<C-d>`) |
| `popupattrs` | `{'maxheight': 12}` | Arguments passed to popup_create() (`:h popup_create-arguments`) |
| `range` | `100` | Lines to search in each batch |
| `timeout` | `200` | Non-async search timeout (ms) |
| `async` | `v:true` | Use asynchronous searching |
| `async_timeout` | `3000` | Async search timeout (ms) |
| `async_minlines` | `1000` | Min lines to trigger async search |
| `highlight` | `v:true` | 'false' to disable menu highlighting (for performance) |
| `trigger` | `t` | `'t'` enables `<Tab>`/`<S-Tab>` as trigger characters, while `'n'` enables `<C-n>`/`<C-p>` and `<Up>/<Down>`. (See note above.) |
| `reverse` | `v:false` | Reverse-sorted menu, with the most relevant item at the bottom (when `pum=v:true`) |
| `prefixlen` | `1` | The minimum prefix length before the completion menu is displayed

> [!IMPORTANT]
> 1. Searching large files will not cause any lag. By default, searching is concurrent. Even though no external jobs are used, a timer pauses the task at regular intervals to check if there are pending keys on the typehead.
> 2. When searching across line boundaries (`\n`), search highlighting will be turned off.

### Applying Configuration

To apply your configuration:

```vim
call g:VimSuggestSetOptions(s:vim_suggest)
```

If you are using [vim-plug](https://github.com/junegunn/vim-plug) you may have to do:

```vim
autocmd VimEnter * call g:VimSuggestSetOptions(s:vim_suggest)
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
- `VimSuggestMute`: Highlights passive text, like line numbers in `grep` output. Linked to `LineNr` by default.

### Customization Examples

```vim
" Customize popup window appearance
let s:vim_suggest.cmd.popupattrs = {
    \ 'borderchars': ['─', '│', '─', '│', '┌', '┐', '┘', '└'],
    \ 'borderhighlight': ['Normal'],
    \ 'highlight': 'Normal',
    \ 'border': [1, 1, 1, 1],
    \ 'maxheight': 20,
    \ }

" Exclude specific patterns from completion
"   To exclude :[N]b[uffer][!] and :[N]sb[uffer][!] do:
let s:vim_suggest.cmd.exclude = [
    \ '^\s*\d*\s*b\%[uffer]!\?\s\+',
    \ '^\s*\d*\s*sb\%[uffer]!\?\s\+'
    \ ]

" Apply the configuration
call g:VimSuggestSetOptions(s:vim_suggest)

" Customize highlight groups
highlight VimSuggestMatch ctermfg=Green guifg=#00FF00
highlight VimSuggestMatchSel cterm=bold gui=bold ctermfg=Green guifg=#00FF00
highlight VimSuggestMute ctermfg=Gray guifg=#808080
```

## Key Bindings

When the popup window is open, you can use the following key mappings:

| Key | Action |
|-----|--------|
| `<PageDown>`/`<S-Down>` | Scroll down one page |
| `<PageUp>`/`<S-Up>` | Scroll up one page |
| `<Tab>` | Move to next item |
| `<Shift-Tab>` | Move to previous item |
| `<C-n>`/`<Down>` | Move to next item (see `trigger` option) |
| `<C-p>`/`<Up>` | Move to previous item  (see `trigger` option) |
| `<Esc>`/`<C-[>`/`<C-c>` | Dismiss popup |
| `<C-s>` | Dismiss auto-completion and revert to default Vim behavior |
| `<C-e>` | Dismiss auto-completion popup temporarily |
| `<Enter>` | Confirm selection |
| `<C-d>` | Open popup menu (override `exclude` list) |
| `<C-j>` | Open file selection in a split window |
| `<C-v>` | Open file selection in a vertical split |
| `<C-t>` | Open file selection in a new tab |
| `<C-q>` | Send items (grep lines or file paths) to the quickfix list |
| `<C-l>` | Send items (file paths) to the argument list |
| `<C-g>` | Copy items to system clipboard (`+` register) |

Note: Keys used in command-line editing (`:h cmdline-editing`) remain unmodified.

> [!TIP]
> 1. To automatically open the quickfix list after using `<C-q>`, add the following to your `.vimrc`:
>    ```vim
>    augroup vimsuggest-qf-show
>        autocmd!
>        autocmd QuickFixCmdPost clist cwindow
>    augroup END
>    ```
> 2. When `<Enter>` is pressed without selection: addons always use first item, other commands do so if `auto_first` is set.
> 3. To perform a multi-word search using the `/` or `?` command, type the first word followed by `<Space>` to trigger auto-completion for the next word. At the end of a line, press `\n` to continue the search on the next line. Note that enabling the fuzzy search option will disable multi-word search functionality.
> 4. When completing files during `:edit` command, `<Tab>` (trigger character) selects subsequent items in the menu. In order to step into a directory select the directory and press `/`; it will populate items from that directory.

### Customizing Key Bindings

You can remap the following keys by configuring the option as shown below:

```vim
let s:vim_suggest.keymap = {
    \ 'page_up': ["\<PageUp>", "\<S-Up>"],
    \ 'page_down': ["\<PageDown>", "\<S-Down>"],
    \ 'hide': "\<C-e>",
    \ 'dismiss': "\<C-s>",
    \ 'send_to_qflist': "\<C-q>",
    \ 'send_to_arglist': "\<C-l>",
    \ 'send_to_clipboard': "\<C-g>",
    \ 'split_open': "\<C-j>",
    \ 'vsplit_open': "\<C-v>",
    \ 'tab_open': "\<C-t>",
\ }
```

Apply the configuration as follows:

```vim
call g:VimSuggestSetOptions(s:vim_suggest)
```

If you are using [vim-plug](https://github.com/junegunn/vim-plug) you may have to do:

```vim
autocmd VimEnter * call g:VimSuggestSetOptions(s:vim_suggest)
```

## Addons

When the `addons` option is set to `v:true`, the following commands are made available. You can use these commands directly or map them to your preferred keys.

1. **Fuzzy Find Files**

   `:VSFind [dirpath] [fuzzy_pattern]`

   This runs the system's `find` program (or alternatives) asynchronously to gather files for fuzzy searching. The optional first argument is the directory to search within.

   Example key mappings:

   ```vim
   nnoremap <key> :VSFind<space>
   nnoremap <key> :VSFind ~/.vim<space>
   nnoremap <key> :VSFind $VIMRUNTIME<space>
   ```

   The 'find' program can be specified through the `g:vimsuggest_fzfindprg` variable. If this variable is not defined, a default command is used (that ignores hidden files and directories). The placeholder "$*" is allowed to specify where the optional directory argument will be included. If placeholder is not specifed, directory name is included at the end. Environment variables and tilde are expanded for directory names.

   ```vim
   let g:vimsuggest_fzfindprg = 'find $* \! \( -path "*/.*" -prune \) -type f -follow'
   let g:vimsuggest_fzfindprg = 'fd --type f .'
   ```

   (Optional) To execute the program through a shell:

   ```vim
   let g:vimsuggest_shell = true
   set shell=/bin/sh
   set shellcmdflag=-c
   ```

   Performance:

   Using the system's `find` program significantly outperforms Vim's `:find` command. On the Vim source repository, it takes ~1 second to list all files using `:find **/*` command, while `:VSFind` takes ~30 milliseconds (30x faster). Shell's recursive glob wildcard can be [slow](https://github.com/vim/vim/issues/15791).

2. **Fuzzy Search Buffers and Other Vim Artifacts**

   ```
   :VSBuffer [fuzzy_pattern]
   :VSGitFind [dir] [fuzzy_pattern]
   :VSMru [fuzzy_pattern]
   :VSKeymap [fuzzy_pattern]
   :VSMark [fuzzy_pattern]
   :VSRegister [fuzzy_pattern]
   :VSChangelist [fuzzy_pattern]
   ```

   - `VSBuffer`: Search and switch between currently open buffers
      - Displays matching buffers as you type
   - `VSGitFind`: Smart file search with Git awareness
      - In Git repositories: Searches tracked files
      - Outside Git (or if 'dir' is given): Falls back to regular file search (like `VSFind`)
   - `VSMru`: Access recently used files
      - Lists files from Vim's `v:oldfiles` history
      - Example: Quickly return to files you edited yesterday
   - `VSKeymap`: Navigate to keymap definitions
      - Opens the source file containing the definition of keymap
   - `VSMark`: Quick mark navigation
      - Jump to any mark location in your files
   - `VSRegister`: Register content access
      - Paste the content of register
   - `VSChangelist`: Navigate through changes
      - Jump to any point in the file's change history
      - See `:help changelist` for details

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
   let g:vimsuggest_grepprg = 'rg --vimgrep --smart-case $* .'
   let g:vimsuggest_grepprg = 'ag --vimgrep'
   ```

4. **Live File Search**

   `:VSFindL {pattern} [directory]`

   This command runs system's `find` program live, showing results as you type. `{pattern}` is a glob (or regex) pattern that should be enclosed in quotes if it contains wildcards. The `find` command is customized via `g:vimsuggest_findprg` (similar to `g:vimsuggest_fzfindprg`).

   Example key mapping and configuring 'find' program:

   ```vim
   nnoremap <key> :VSFindL "*"<left><left>
   let g:vimsuggest_findprg = 'find -EL $* \! \( -regex ".*\.(swp\|git)" -prune \) -type f -name $*'
   " Using fd:
   nnoremap <key> :VSFindL<space>
   let g:vimsuggest_findprg = 'fd --type f'
   let g:vimsuggest_findprg = 'fd --type f --glob'
   ```

5. **In-Buffer Search (`:h :global`)**

   `:VSGlobal {regex_pattern}`

   Use this for a powerful in-buffer search with Vim's regex. For example, to list all functions and classes in a Python file and jump quickly:

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

   `:VSExec {shell_command}`

   This command runs any shell command using your `$SHELL` environment, allowing features like brace expansion and globbing. Errors are ignored. However, `:VSGrep` and `VSFindL` commands are less clunky.

   Example key mappings:

   ```vim
   nnoremap <key> :VSExec fd --type f<space>
   nnoremap <key> :VSExec grep -RIHins "" . --exclude-dir={.git,"node_*"} --exclude=".*"<c-left><c-left><c-left><left><left>
   " Easier to type but low performance:
   nnoremap <key> :VSExec grep -IHins "" **/*<c-left><left><left>
   ```

> [!IMPORTANT]
> External programs are executed directly if `g:vimsuggest_shell` is `v:false`. Otherwise, they are executed through shell as specified in `shell` option (`:h 'shell'`). Using shell allows for expansion of `~`, `$VAR`, `**` (if your shell supports), etc.
> ```vim
> let g:vimsuggest_shell = v:true
> set shell=/bin/zsh
> set shellcmdflag=-c
> ```
> See also `:h expandcmd()`

> [!TIP]
> If these commands aren't sufficient, you can define your own using the examples provided in `autoload/vimsuggest/addons/addons.vim` script. Legacy script users can import using `:import` also (see `:h import-legacy`).

## Other Plugins

For insert-mode auto-completion, try [**Vimcomplete**](https://github.com/girishji/vimcomplete).

## Contributing

Open an issue if you encounter problems. Pull requests are welcomed.

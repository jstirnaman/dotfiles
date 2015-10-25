set nocompatible              " be iMproved, required
filetype off                  " required

" set the runtime path to include Vundle and initialize
set rtp+=~/.vim/bundle/Vundle.vim
"set hlsearch
" Use the space key as our leader. Put this near the top of your vimrc
let mapleader = "\<Space>"

call vundle#begin()
" alternatively, pass a path where Vundle should install plugins
"call vundle#begin('~/some/path/here')

" let Vundle manage Vundle, required
Plugin 'gmarik/Vundle.vim'
" Three-way diffing
" Plugin 'sjl/threesome.vim'
" The following are examples of different formats supported.
" Keep Plugin commands between vundle#begin/end.
" plugin on GitHub repo
Plugin 'tpope/vim-fugitive'
" plugin from http://vim-scripts.org/vim/scripts.html
Plugin 'L9'
" Git plugin not hosted on GitHub
" Plugin 'git://git.wincent.com/command-t.git'
" git repos on your local machine (i.e. when working on your own plugin)
" Plugin 'file:///home/gmarik/path/to/plugin'
" The sparkup vim script is in a subdirectory of this repo called vim.
" Pass the path to set the runtimepath properly.
Plugin 'rstacruz/sparkup', {'rtp': 'vim/'}
Plugin 'godlygeek/tabular'
Plugin 'plasticboy/vim-markdown'
" Avoid a name conflict with L9
Plugin 'jstirnaman/L9', {'name': 'newL9'}
Plugin 'thoughtbot/vim-rspec'
Plugin 'jgdavey/tslime.vim'
Plugin 'flazz/vim-colorschemes'
Plugin 'scrooloose/syntastic'
Plugin 'christoomey/vim-tmux-navigator'
" All of your Plugins must be added before the following line
call vundle#end()            " required
filetype plugin indent on    " required
" To ignore plugin indent changes, instead use:
"filetype plugin on
"
" Brief help
" :PluginList       - lists configured plugins
" :PluginInstall    - installs plugins; append `!` to update or just :PluginUpdate
" :PluginSearch foo - searches for foo; append `!` to refresh local cache
" :PluginClean      - confirms removal of unused plugins; append `!` to auto-approve removal
"
" see :h vundle for more details or wiki for FAQ
" Put your non-Plugin stuff after this line
" Tell vim-rspec to use Send_to_Tmux
let g:rspec_command = 'call Send_to_Tmux("bundle exec rspec {spec}\n")'

" vim-rspec mappings
map <Leader>t :call RunCurrentSpecFile()<CR>
map <Leader>s :call RunNearestSpec()<CR>
map <Leader>l :call RunLastSpec()<CR>
map <Leader>a :call RunAllSpecs()<CR>
syntax on
set expandtab
autocmd Filetype html setlocal ts=2 sts=2 sw=2
autocmd Filetype ruby setlocal ts=2 sts=2 sw=2
autocmd Filetype javascript setlocal ts=4 sts=4 sw=4
let ruby_space_errors = 1
" Mark syntax errors with :signs
let g:syntastic_enable_signs=1
" Do not automatically jump to error
let g:syntastic_auto_jump=0
" Show error list automatically
let g:syntastic_auto_loc_list=1
" Syntax checkers:
"let g:syntastic_ruby_checkers=['rubocop', 'mri']
let g:syntastic_python_checkers=['pep8', 'pylint', 'python']
let g:syntastic_javascript_checkers=['jshint']

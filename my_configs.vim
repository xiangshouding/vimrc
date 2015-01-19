set nu
set guifont=Source\ Code\ Pro:h15

colorscheme smyck
set cursorline

" close fold
set foldlevel=1000

" key map

map <leader>q :q!<cr>

" https://github.com/mattn/emmet-vim/issues/159#issuecomment-26300032
imap <expr> <tab> emmet#expandAbbrIntelligent("\<tab>")

"""""""""""""""""""""""""""""""""""""""
" plugin settings                     "
"""""""""""""""""""""""""""""""""""""""

" Tagbar
nmap <leader>tt :TagbarToggle<CR>
let g:tagbar_autofocus = 0

let g:tagbar_type_go = {
    \ 'ctagstype' : 'go',
    \ 'kinds'     : [
        \ 'p:package',
        \ 'i:imports:1',
        \ 'c:constants',
        \ 'v:variables',
        \ 't:types',
        \ 'n:interfaces',
        \ 'w:fields',
        \ 'e:embedded',
        \ 'm:methods',
        \ 'r:constructor',
        \ 'f:functions'
    \ ],
    \ 'sro' : '.',
    \ 'kind2scope' : {
        \ 't' : 'ctype',
        \ 'n' : 'ntype'
    \ },
    \ 'scope2kind' : {
        \ 'ctype' : 't',
        \ 'ntype' : 'n'
    \ },
    \ 'ctagsbin'  : 'gotags',
    \ 'ctagsargs' : '-sort -silent'
\ }

" vim powerline
" let g:Powerline_symbols='fancy'
"

hi! VertSplit guifg=fg guibg=bg gui=NONE

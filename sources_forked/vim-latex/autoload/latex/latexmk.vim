" LaTeX plugin for Vim
"
" Maintainer: Karl Yngve Lervåg
" Email:      karl.yngve@gmail.com
"

function! latex#latexmk#init(initialized) " {{{1
  call latex#util#set_default('g:latex_latexmk_enabled', 1)
  if !g:latex_latexmk_enabled | return | endif

  " Set default options
  call latex#util#set_default('g:latex_latexmk_callback', 1)
  call latex#util#set_default('g:latex_latexmk_continuous', 1)
  call latex#util#set_default('g:latex_latexmk_background', 0)
  call latex#util#set_default('g:latex_latexmk_options', '-pdf')
  call latex#util#set_default('g:latex_latexmk_build_dir', '.')
  call latex#util#set_default('g:latex_quickfix_autojump', '0')
  call latex#util#set_default('g:latex_quickfix_mode', '2')
  call latex#util#set_default('g:latex_quickfix_open_on_warning', '1')
  call latex#util#error_deprecated('g:latex_latexmk_autojump')
  call latex#util#error_deprecated('g:latex_latexmk_quickfix')
  call latex#util#error_deprecated('g:latex_latexmk_output')

  " Check system compatibility
  if s:system_incompatible() | return | endif

  " Initialize pid for current tex file
  if !has_key(g:latex#data[b:latex.id], 'pid')
    let g:latex#data[b:latex.id].pid = 0
  endif

  " Define commands
  com! -buffer VimLatexCompile       call latex#latexmk#compile()
  com! -buffer VimLatexCompileToggle call latex#latexmk#toggle()
  com! -buffer VimLatexStop          call latex#latexmk#stop()
  com! -buffer VimLatexStopAll       call latex#latexmk#stop_all()
  com! -buffer -bang VimLatexErrors  call latex#latexmk#errors(<q-bang> == "!")
  com! -buffer VimLatexOutput        call latex#latexmk#output()
  com! -buffer -bang VimLatexClean   call latex#latexmk#clean(<q-bang> == "!")
  com! -buffer -bang VimLatexStatus  call latex#latexmk#status(<q-bang> == "!")
  com! -buffer -bang VimLatexCompileSS
        \ call latex#latexmk#compile_singleshot(<q-bang> == "!")

  " Set default mappings
  if g:latex_mappings_enabled
    nnoremap <silent><buffer> <localleader>ll :call latex#latexmk#toggle()<cr>
    nnoremap <silent><buffer> <localleader>lc :call latex#latexmk#clean(0)<cr>
    nnoremap <silent><buffer> <localleader>lC :call latex#latexmk#clean(1)<cr>
    nnoremap <silent><buffer> <localleader>lg :call latex#latexmk#status(0)<cr>
    nnoremap <silent><buffer> <localleader>lG :call latex#latexmk#status(1)<cr>
    nnoremap <silent><buffer> <localleader>lk :call latex#latexmk#stop()<cr>
    nnoremap <silent><buffer> <localleader>lK :call latex#latexmk#stop_all()<cr>
    nnoremap <silent><buffer> <localleader>le :call latex#latexmk#errors(1)<cr>
    nnoremap <silent><buffer> <localleader>lo :call latex#latexmk#output()<cr>
  endif

  " The remaining part is only relevant for continuous mode
  if !g:latex_latexmk_continuous | return | endif

  " Ensure that all latexmk processes are stopped when vim exits
  " Note: Only need to define this once, globally.
  if !a:initialized
    augroup latex_latexmk
      autocmd!
      autocmd VimLeave * call latex#latexmk#stop_all()
    augroup END
  endif

  " If all buffers for a given latex project are closed, kill latexmk
  " Note: This must come after the above so that the autocmd group is properly
  "       refreshed if necessary
  augroup latex_latexmk
    autocmd BufUnload <buffer> call s:stop_buffer()
  augroup END
endfunction

" }}}1
function! latex#latexmk#clean(full) " {{{1
  let data = g:latex#data[b:latex.id]
  if data.pid
    echomsg "latexmk is already running"
    return
  endif

  "
  " Run latexmk clean process
  "
  if has('win32')
    let cmd = 'cd /D ' . shellescape(data.root) . ' & '
  else
    let cmd = 'cd ' . shellescape(data.root) . '; '
  endif
  let cmd .= 'latexmk -outdir=' . g:latex_latexmk_build_dir
  if a:full
    let cmd .= ' -C '
  else
    let cmd .= ' -c '
  endif
  let cmd .= shellescape(data.base)
  let g:latex#data[b:latex.id].cmds.clean = cmd
  let exe = {
        \ 'cmd' : cmd,
        \ 'bg'  : 0,
        \ }
  call latex#util#execute(exe)

  if a:full
    echomsg "latexmk full clean finished"
  else
    echomsg "latexmk clean finished"
  endif
endfunction

" }}}1
function! latex#latexmk#toggle() " {{{1
  let data = g:latex#data[b:latex.id]

  if data.pid
    call latex#latexmk#stop()
  else
    call latex#latexmk#compile()
  endif
endfunction

" }}}1
function! latex#latexmk#compile() " {{{1
  let data = g:latex#data[b:latex.id]

  if data.pid
    echomsg "latexmk is already running for `" . data.base . "'"
    return
  endif

  call s:latexmk_set_cmd(data)

  " Start latexmk
  let exe = {}
  let exe.null = 0
  if !g:latex_latexmk_continuous && !g:latex_latexmk_background
    let exe.bg = 0
    let exe.silent = 0
  endif
  let exe.cmd  = data.cmds.compile
  call latex#util#execute(exe)

  if g:latex_latexmk_continuous
    call s:latexmk_set_pid(data)
    echomsg 'latexmk continuous mode started successfully'

    " Get window ID
    if g:latex_view_method == 'mupdf'
      " give time to read window ID
      sleep
      let cmd  = 'xdotool search --class MuPDF'
      let mupdf_ids = systemlist(cmd)

      if len(mupdf_ids) == 0
        let g:latex#data[b:latex.id].mupdf_id = 0
      else
        let g:latex#data[b:latex.id].mupdf_id = mupdf_ids[-1]
      endif
    endif
  else

    echomsg 'latexmk compiling'
  endif
endfunction

" }}}1
function! latex#latexmk#compile_singleshot(verbose) " {{{1
  let data = g:latex#data[b:latex.id]

  if data.pid
    echomsg "latexmk is already running for `" . data.base . "'"
    return
  endif

  let l:latex_latexmk_continuous = g:latex_latexmk_continuous
  let g:latex_latexmk_continuous = 0
  call s:latexmk_set_cmd(data)
  let g:latex_latexmk_continuous = l:latex_latexmk_continuous

  " Start latexmk
  let exe = {}
  let exe.null = 0
  if a:verbose
    let exe.bg = 0
    let exe.silent = 0
  endif
  let exe.cmd  = data.cmds.compile
  call latex#util#execute(exe)
endfunction

" }}}1
function! latex#latexmk#errors(force) " {{{1
  cclose

  let log = g:latex#data[b:latex.id].log()
  if empty(log)
    if a:force
      echo "No log file found!"
    endif
    return
  endif

  if g:latex_quickfix_autojump
    execute 'cfile ' . fnameescape(log)
  else
    execute 'cgetfile ' . fnameescape(log)
  endif

  "
  " There are two options that determine when to open the quickfix window.  If
  " forced, the quickfix window is always opened when there are errors or
  " warnings (forced typically imply that the functions is called from the
  " normal mode mapping).  Else the behaviour is based on the settings.
  "
  let open_quickfix_window = a:force
        \ || (g:latex_quickfix_mode > 0
        \     && (g:latex_quickfix_open_on_warning
        \         || s:log_contains_error(log)))

  if open_quickfix_window
    botright cwindow
    if g:latex_quickfix_mode == 2
      wincmd p
    endif
    redraw!
  endif
endfunction

" }}}1
function! latex#latexmk#output() " {{{1
  if has_key(g:latex#data[b:latex.id], 'tmp')
    let tmp = g:latex#data[b:latex.id].tmp
  else
    echo "vim-latex: No output exists"
    return
  endif

  " Create latexmk output window
  if bufnr(tmp) >= 0
    silent exe 'bwipeout' . bufnr(tmp)
  endif
  silent exe 'split ' . tmp

  " Better automatic update
  augroup tmp_update
    autocmd!
    autocmd BufEnter        * silent! checktime
    autocmd CursorHold      * silent! checktime
    autocmd CursorHoldI     * silent! checktime
    autocmd CursorMoved     * silent! checktime
    autocmd CursorMovedI    * silent! checktime
  augroup END
  silent exe 'autocmd! BufDelete ' . tmp . ' augroup! tmp_update'

  " Set some mappings
  nnoremap <buffer> <silent> q :bwipeout<cr>

  " Set some buffer options
  setlocal autoread
  setlocal nomodifiable
endfunction

" }}}1
function! latex#latexmk#status(detailed) " {{{1
  if a:detailed
    let running = 0
    for data in g:latex#data
      if data.pid
        if !running
          echo "latexmk is running"
          let running = 1
        endif

        let name = data.tex
        if len(name) >= winwidth('.') - 20
          let name = "..." . name[-winwidth('.')+23:]
        endif

        echom printf('pid: %6s, file: %-s', data.pid, name)
      endif
    endfor

    if !running
      echo "latexmk is not running"
    endif
  else
    if g:latex#data[b:latex.id].pid
      echo "latexmk is running"
    else
      echo "latexmk is not running"
    endif
  endif
endfunction

" }}}1
function! latex#latexmk#stop() " {{{1
  let pid  = g:latex#data[b:latex.id].pid
  let base = g:latex#data[b:latex.id].base
  if pid
    call s:latexmk_kill_pid(pid)
    let g:latex#data[b:latex.id].pid = 0
    echo "latexmk stopped for `" . base . "'"
  else
    echo "latexmk is not running for `" . base . "'"
  endif
endfunction

" }}}1
function! latex#latexmk#stop_all() " {{{1
  for data in g:latex#data
    if data.pid
      call s:latexmk_kill_pid(data.pid)
      let data.pid = 0
    endif
  endfor
endfunction

" }}}1

" Helper functions for latexmk command
function! s:latexmk_set_cmd(data) " {{{1
  " Note: We don't send output to /dev/null, but rather to a temporary file,
  "       which allows inspection of latexmk output
  let tmp = tempname()

  if has('win32')
    let cmd  = 'cd /D ' . shellescape(a:data.root)
    let cmd .= ' && set max_print_line=2000 & latexmk'
  else
    let cmd  = 'cd ' . shellescape(a:data.root)
    let cmd .= ' && max_print_line=2000 latexmk'
  endif

  let cmd .= ' ' . g:latex_latexmk_options
  let cmd .= ' -e ' . shellescape('$pdflatex =~ s/ / -file-line-error /')
  let cmd .= ' -outdir=' . g:latex_latexmk_build_dir

  if g:latex_latexmk_continuous
    let cmd .= ' -pvc'
    if g:latex_latexmk_callback && has('clientserver')
      let callback  = v:progname
      let callback .= ' --servername ' . v:servername
      let callback .= ' --remote-expr \"latex\#latexmk\#errors(0)\"'
      if has('win32')
        let cmd .= ' -e "$success_cmd .= ''' . callback . '''"'
              \ .  ' -e "$failure_cmd .= ''' . callback . '''"'
      else
        let cmd .= ' -e ''$success_cmd .= "' . callback . '"'''
              \ .  ' -e ''$failure_cmd .= "' . callback . '"'''
      endif
    endif
  endif

  let cmd .= ' ' . shellescape(a:data.base)

  if g:latex_latexmk_continuous || g:latex_latexmk_background
    if has('win32')
      let cmd .= ' >'  . tmp
      let cmd = 'cmd /s /c "' . cmd . '"'
    else
      let cmd .= ' &>' . tmp
    endif
  endif

  let a:data.cmds.compile = cmd
  let a:data.tmp = tmp
endfunction

" }}}1
function! s:latexmk_set_pid(data) " {{{1
  if has('win32')
    let pidcmd = 'qprocess latexmk.exe'
    let pidinfo = systemlist(pidcmd)[-1]
    let a:data.pid = split(pidinfo,'\s\+')[-2]
  else
    let a:data.pid = system('pgrep -nf "^perl.*latexmk"')[:-2]
  endif
endfunction

function! s:latexmk_kill_pid(pid) " {{{1
  let exe = {}
  let exe.bg = 0
  let exe.null = 0

  if has('win32')
    let exe.cmd = 'taskkill /PID ' . a:pid . ' /T /F'
  else
    let exe.cmd = 'kill ' . a:pid
  endif

  call latex#util#execute(exe)
endfunction

" }}}1

function! s:log_contains_error(logfile) " {{{1
  let lines = readfile(a:logfile)
  let lines = filter(lines, 'v:val =~ ''^.*:\d\+: ''')
  let lines = uniq(map(lines, 'matchstr(v:val, ''^.*\ze:\d\+:'')'))
  let lines = map(lines, 'fnameescape(fnamemodify(v:val, '':p''))')
  let lines = filter(lines, 'filereadable(v:val)')
  return len(lines) > 0
endfunction

function! s:stop_buffer() " {{{1
  "
  " Only run if latex variables are set
  "
  if !exists('b:latex') | return | endif
  let id = b:latex.id
  let pid = g:latex#data[id].pid

  "
  " Only stop if latexmk is running
  "
  if pid
    "
    " Count the number of buffers that point to current latex blob
    "
    let n = 0
    for b in filter(range(1, bufnr("$")), 'buflisted(v:val)')
      if id == getbufvar(b, 'latex', {'id' : -1}).id
        let n += 1
      endif
    endfor

    "
    " Only stop if current buffer is the last for current latex blob
    "
    if n == 1
      silent call latex#latexmk#stop()
    endif
  endif
endfunction

function! s:system_incompatible() " {{{1
  if has('win32')
    let required = ['latexmk']
  else
    let required = ['latexmk', 'pgrep']
  endif

  "
  " Check for required executables
  "
  for cmd in required
    if !executable(cmd)
      echom "Warning: Could not initialize latex#latexmk"
      echom "         Missing executable: " . cmd
      return 1
    endif
  endfor
endfunction

" }}}1

" vim: fdm=marker sw=2

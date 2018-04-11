" Description: Omni completion for CMake
" Maintainer:  Richard Quirk richard.quirk at gmail.com
" License:     Apache License 2.0
"
" To install cmake completion, copy the contents of this file to
"   $HOME/.vim/autoload/cmakecomplete.vim
" And the associated plugin file to:
"   $HOME/.vim/plugin/cmake.vim
" Then in a CMakeLists.txt file, use C-X C-O to autocomplete cmake
" keywords with the corresponding info shown in the info buffer.

"""
" Copyright 2009 Richard Quirk
"
" Licensed under the Apache License, Version 2.0 (the "License"); you may not
" use this file except in compliance with the License. You may obtain a copy of
" the License at http://www.apache.org/licenses/LICENSE-2.0
"
" Unless required by applicable law or agreed to in writing, software
" distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
" WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
" License for the specific language governing permissions and limitations under
" the License.
"""
if version < 700
  finish
endif
let s:keepcpo= &cpo
set cpo&vim

" this is the list of potential completions
let s:cmake_commands = []
let s:cmake_properties = []
let s:cmake_modules = []
let s:cmake_variables = []
let s:cmake_command_examples = {}

function s:createbuffer()
  let counter = 0
  let versionedName = 'cmake help (' . counter . ')'
  while buflisted(versionedName)
    let counter += 1
    let versionedName = 'cmake help (' . counter . ')'
  endwhile
  return versionedName
endfunction

function cmakecomplete#Help(...)
  " create a new buffer and show all of cmake's help there
  let output = ""
  if a:0 == 1
    let arg = tolower(a:1)
    let searchlist = [s:cmake_commands, s:cmake_properties, s:cmake_modules, s:cmake_variables]
    for sl in searchlist
      for m in sl
        if m['word'] == arg
          let output = m['info']
          break
        endif
      endfor
      if output != ""
        break
      endif
    endfor
  else
    let output = system('cmake --help-full')
  endif
  if output == ""
    echoerr "No help found for that"
    return
  endif
  pc
  exec "above ". winheight(0) / 3 . " split"
  let bufferName=s:createbuffer()
  edit `=bufferName`
  setlocal buftype=nofile
  setlocal previewwindow
  setlocal readonly
  setlocal noswapfile
  setlocal bufhidden=delete
  silent 0put=output
  let &filetype = 'rst'
  setlocal nomodifiable
  0
endfunction

function cmakecomplete#AddWord(word, info, list, ignore_case)
  " strip the leading spaces, add the info
  call add(a:list, {'word': substitute(a:word, '^\W\+', '', 'g'),
        \ 'icase': a:ignore_case,
        \ 'info': a:info})
endfunction

function cmakecomplete#PrintExamples()
  echo len(s:cmake_command_examples)
  echo s:cmake_command_examples
endfunc

function cmakecomplete#Version()
  let output = system('cmake --version')
  for c in split(output, '\n')
    if c =~ 'version'
      let components = split(c, ' ')
      return components[len(components) - 1]
    endif
  endfor
endfunc

function cmakecomplete#Init3(help, list, ignore_case)
  " parse the help to get completions
  let oldic = &ignorecase
  set noignorecase
  let output = system('cmake --help-' . a:help)
  let word = ''
  let info = []
  let in_example = 0
  let last_line = ''
  for c in split(output, '\n')
    " CMake commands now have a line of dashes after them...
    if c =~ '^-\+$'
      if word != ''
        call cmakecomplete#AddWord(word, join(info[0:len(info) - 3], ''), a:list, a:ignore_case)
      endif
      let info = [last_line, "\n", c]
      let word = substitute(last_line, '^\s\+', '', 'g')
      let last_line = c
    else
      let last_line = c
      " if we have a command, then the rest is the help
      if word != ''
        " extract examples...
        if in_example == 0 && a:help == 'commands' && c =~ '^\s' . word
          let in_example = 1
          let example = substitute(c, '\W', ' ', 'g')
        elseif in_example == 1
          if c =~ '^\s*$'
            if !has_key(s:cmake_command_examples, word)
              let s:cmake_command_examples[word] = ''
            endif
            let s:cmake_command_examples[word] = s:cmake_command_examples[word] . ' ' . example
            let in_example = 0
          else
            let example = example . " " . substitute(c, '\W', ' ', 'g')
          endif
        endif
        let info += [c, "\n"]
      endif
    endif
  endfor
  " add the last command to the list
  if word != ''
    call cmakecomplete#AddWord(word, join(info[0: len(info) - 3], ''), a:list, a:ignore_case)
  endif
  let &ignorecase = oldic
endfunction

function cmakecomplete#Init(help, list, ignore_case)
  " parse the help to get completions
  let oldic = &ignorecase
  set noignorecase
  let output = system('cmake --help-' . a:help)
  let word = ''
  let info = ''
  let re = '^\W\W[a-zA-Z_]\+$'
  if !a:ignore_case
    let re = '^\W\W[A-Z_]\+$'
  endif
  let in_example = 0
  for c in split(output, '\n')
    " CMake commands start with 2 blanks and then a lowercase letter
    if c =~ re
      if word != ''
        call cmakecomplete#AddWord(word, info, a:list, a:ignore_case)
      endif
      let info = c . "\n"
      let word = substitute(c, '^\s\+', '', 'g')
    else
      " if we have a command, then the rest is the help
      if word != ''
        " extract examples...
        if in_example == 0 && a:help == 'commands' && c =~ '^\s\{9}' . word
          let in_example = 1
          let example = substitute(c, '\W', ' ', 'g')
        elseif in_example == 1
          if c =~ '^\s*$'
            if !has_key(s:cmake_command_examples, word)
              let s:cmake_command_examples[word] = ''
            endif
            let s:cmake_command_examples[word] = s:cmake_command_examples[word] . ' ' . example
            let in_example = 0
          else
            let example = example . " " . substitute(c, '\W', ' ', 'g')
          endif
        endif
        " End of the help is marked with line of dashes
        " But only after getting at least one command
        if c =~ '^-\+$'
          continue
        endif
        let info = info . c . "\n"
      endif
    endif
  endfor
  " add the last command to the list
  if word != ''
    call cmakecomplete#AddWord(word, info, a:list, a:ignore_case)
  endif
  let &ignorecase = oldic
endfunction

function! cmakecomplete#InComment()
  return match(synIDattr(synID(line("."), col(".")-1, 1), "name"), '\<cmakeComment') >= 0
endfunction

function! cmakecomplete#InVariable()
  let here = line('.')
  let openb = search('${', 'bn', line("w0"), 500)
  if openb == 0
    return 0
  endif
  let closeb = search('}', 'bn', openb, 500)
  return closeb == 0 && openb <= here
endfunction

function! cmakecomplete#InFunction()
  let here = line('.')
  let openb = search('(', 'bn', line("w0"), 500)
  if openb == 0
    return 0
  endif
  let closeb = search(')', 'bn', openb, 500)
  return closeb == 0 && openb <= here
endfunction

function! cmakecomplete#InFunctionName()
  let here = line('.')
  let [openl, openc] = searchpos('[a-zA-Z_]\+\s*(', 'bn', line("w0"), 500)
  if openl == 0
    return ""
  endif
  let closeb = search(')', 'bn', openl, 500)
  if closeb == 0 && openl <= here
    return substitute(getline(openl)[(openc - 1):], '\s*(.*', '', 'g')
  endif
  return ""
endfunction

function! cmakecomplete#InInclude()
  let here = line('.')
  let openb = search('include(', 'bn', line("w0"), 500)
  if openb == 0
    return 0
  endif
  let closeb = search(')', 'bn', openb, 500)
  return closeb == 0 && openb <= here
endfunction

function! cmakecomplete#GetArguments(info)
  let oldic = &ignorecase
  set noignorecase
  let words = map(filter(split(s:cmake_command_examples[a:info]),
        \ 'v:val == toupper(v:val)'),
        \ "{'word': v:val, " .
        \ " 'icase ': 0 }")
  let &ignorecase = oldic
  return words
endfunc

function! cmakecomplete#PreviousWord()
  let here = line('.')
  let openb = search('(', 'bn', line("w0"), 500)
  if openb == 0
    return ""
  endif
  let closeb = search(')', 'bn', openb, 500)
  if closeb == 0 && openb <= here
    let propw = search('\<properties\>', 'bn', openb, 500)
    if propw
      return "PROPERTIES"
    endif
  endif
  return ""
endfunc

function! cmakecomplete#Complete(findstart, base)
  if a:findstart == 1
    let s:cmakeNoComplete = 0
    " first time, wants to know where the word starts
    if cmakecomplete#InComment()
      let s:cmakeNoComplete = 1
      return -1
    endif
    let linestr = getline('.')
    let start = col('.') - 1
    while start > 0 && linestr[start - 1] =~ '[a-zA-Z_]'
      let start -= 1
    endwhile
    let s:compl_context = linestr[0:col('.')-2]
    return start
  endif
  if exists("s:compl_context")
    let linestr = s:compl_context
    unlet! s:compl_context
  else
    let linestr = a:base
  endif

  if s:cmakeNoComplete
    return []
  endif

  let res = []
  let list = s:cmake_commands
  let match = '^' . tolower(a:base)
  if cmakecomplete#InVariable()
    let match = '^' . a:base
    let list = s:cmake_variables
  elseif cmakecomplete#InInclude()
    " return modules
    let match = '^' . a:base
    let list = s:cmake_modules
  elseif cmakecomplete#InFunction()
    " return completion variables
    let match = '^' . a:base
    let fname = cmakecomplete#InFunctionName()
    if has_key(s:cmake_command_examples, fname)
      let list = cmakecomplete#GetArguments(fname)
    else
      let list = s:cmake_properties
    endif
    let prevword = cmakecomplete#PreviousWord()
    if prevword == "PROPERTIES"
      let list = s:cmake_properties
    endif
  endif
  " return the completion words
  for m in list
    if m['word'] =~ match
      call add(res, m)
    endif
  endfor
  " problem here: always returns lower case
  return res
endfunction

function cmakecomplete#HelpComplete(ArgLead, CmdLine, CursorPos)
  let result = []
  let match = '^' . a:ArgLead
  for m in s:cmake_commands
    let w = m['word']
    if w =~ match
      call add(result, w)
    endif
  endfor
  return result
endfunction

if cmakecomplete#Version() =~ "^2\."
call cmakecomplete#Init('commands', s:cmake_commands, 1)
call cmakecomplete#Init('properties', s:cmake_properties, 0)
call cmakecomplete#Init('modules', s:cmake_modules, 1)
call cmakecomplete#Init('variables', s:cmake_variables, 1)
else
call cmakecomplete#Init3('commands', s:cmake_commands, 1)
call cmakecomplete#Init3('properties', s:cmake_properties, 0)
call cmakecomplete#Init3('modules', s:cmake_modules, 1)
call cmakecomplete#Init3('variables', s:cmake_variables, 1)
endif

let &cpo = s:keepcpo
unlet s:keepcpo

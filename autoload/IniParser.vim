" File: autoload/IniParser.vim
" version 0.2
" See doc/IniParser.txt for more information.

let s:saved_cpo = &cpo
set cpo&vim

function! IniParser#GetVersion() " {{{1
    " Get the version number. It equals to the version number times 100. For
    " example, version 0.1 is corresponding to 10, version 2.3 is
    " corresponding to 230

    return 20
endfunction

" utils {{{1
function! s:DictModifyReclusively(dict, ...) " {{{2

    if a:0 == 0 || (a:0 == 1 && type(a:1) != type([]))
        echohl ErrorMsg | 
                    \echo 'IniParser: DictModifyReclusively parameter error!' 
                    \| echohl None
        return -1
    endif
    
    if type(a:1) == type([])
        let l:key_val_list = a:1
        if len(l:key_val_list) < 2
            echohl ErrorMsg | 
                        \echo 
                        \'IniParser: DictModifyReclusively parameter error!'
                        \| echohl None
            return -1
        endif
    else
        let l:key_val_list = a:000
    endif

    let l:tmp_dict = a:dict

    for i in range(len(l:key_val_list) - 2)
        if !has_key(l:tmp_dict, l:key_val_list[i])
            let l:tmp_dict[l:key_val_list[i]] = {}
        elseif type(l:tmp_dict[l:key_val_list[i]]) != type({})
            unlet! l:tmp_dict[l:key_val_list[i]]
            let l:tmp_dict[l:key_val_list[i]] = {}
        endif

        let l:tmp_dict = l:tmp_dict[l:key_val_list[i]]
    endfor

    " for the last parameter, it's the value
    if has_key(l:tmp_dict, l:key_val_list[len(l:key_val_list)-2])
        unlet! l:tmp_dict[l:key_val_list[len(l:key_val_list)-2]]
    endif

    let l:tmp_dict[l:key_val_list[len(l:key_val_list)-2]] = 
                \l:key_val_list[len(l:key_val_list)-1]

    return 0
endfunction

function! s:TrimString(str, ...) " {{{2

    if a:0 == 1
        let l:blank_chars = a:1
    else
        let l:blank_chars = " \t"
    endif


    if strlen(a:str) == 0
        return ''
    endif

    if strlen(a:str) == 1
        if match(l:blank_chars, a:str[0])
            return a:str
        else
            return ''
        endif
    endif

    let l:str_begin = 0
    let l:str_end = strlen(a:str)

    for i in range(strlen(a:str))
        let l:str_begin = i
        if match(l:blank_chars, a:str[i]) == -1
            break
        endif
    endfor

    for i in range(strlen(a:str)-1, 0, -1)
        let l:str_end = i
        if match(l:blank_chars, a:str[i]) == -1
            break
        endif
    endfor

    if l:str_end < l:str_begin
        return ''
    endif

    return strpart(a:str, l:str_begin, l:str_end-l:str_begin+1)
endfunction

function! IniParser#Read(arg) " {{{1
    " Read the ini file, the parameter could be either a file name or a list
    " containing the lines of the ini file.

    if type(a:arg) == type('')
        " this is a file name when a:arg is a string. Read the file and then
        " call the function with a list parameter.

        if !filereadable(a:arg)
            " if file is not readable, return 1

            return 1
        endif

        return IniParser#Read(readfile(a:arg))

    elseif type(a:arg) != type([])
        " if the type is neither a string nor a list, returns 2        

        return 2
    endif

    let l:result_dic = {}
    let l:cur_group = [] " group indicated by '[]' in the ini file

    for line in a:arg
        let line = s:TrimString(line)
        let l:line_len = strlen(line)

        if l:line_len == 0 || line[0] == ';' || line[0] == '#'
        " it's a comment line or empty line
        " do nothing

        elseif line[0] == '[' && line[l:line_len-1] == ']' && l:line_len > 2
        " it's a group if the first character is '[' and the last is ']'

            " set current group to what inside the '[]'
            let l:cur_group =
                        \split(strpart(line, 1, l:line_len-2), '/')
        elseif !empty(l:cur_group) && match(line, '=') != -1
        " it's an entry line

            " copy l:cur_group
            let l:list_to_add = deepcopy(l:cur_group)

            " find the '=' position
            let l:eq_position = match(line, '=')

            " l:eq_left is the string at the left of the '='. split it by '/'
            " because this also changes group.
            let l:eq_left = strpart(line, 0, l:eq_position)
            call extend(l:list_to_add, split(l:eq_left, '/'))

            " add the string at the right side of the '=' directly
            call add(l:list_to_add, strpart(line, l:eq_position + 1, 
                        \l:line_len - l:eq_position - 1))
            call s:DictModifyReclusively(l:result_dic, l:list_to_add)
        else
        " should be a syntax error. Don't give an error message on the screen,
        " just return 0 to tell the caller
            return 0
        endif
    endfor

    return l:result_dic
endfunction

function! s:WriteToList(ini_sub_dict, prefix) " {{{1

    let l:ret_list = []

    for key in keys(a:ini_sub_dict)
        let l:value = a:ini_sub_dict[key]

        if type(l:value) == type({})
            call extend(l:ret_list, s:WriteToList(l:value, prefix.key.'/'))
        elseif type(l:value) == type('')
            call add(l:ret_list, a:prefix.key.'='.l:value)
        endif
    endfor

    return l:ret_list
endfunction

function! IniParser#Write(ini_dict, ...) " {{{1
    " write to ini file, the first argument is a dict, whose format is the
    " same with the return value of IniParser#Read; if the second argument is
    " provided, it should be the ini file name which we want to write to, and
    " the function will try to write to the file. If the second argument is
    " not provided, then the function will not write anything to file. If any
    " error occured, the return value is a number. If the function succeeds,
    " the return value is a list containing the content of the ini file. The
    " format of the list is the same as the list argument of the function
    " writefile().

    if type(a:ini_dict) != type({})
        return 1
    endif

    let l:ini_list = []

    " write to the list
    for key in keys(a:ini_dict)
        call add(l:ini_list, '['.key.']')
        let l:value = a:ini_dict[key]

        if type(l:value) == type({})
            call extend(l:ini_list, s:WriteToList(l:value, ''))
        endif
    endfor

    " write to the file if the second parameter is given
    if a:0 == 1 && type(a:1) == type('')
        if writefile(l:ini_list, a:1) == -1
            return 2
        endif
    endif

    return l:ini_list
endfunction

" }}}

let &cpo = s:saved_cpo
unlet! s:saved_cpo

" vim: fdm=marker et ts=4 tw=78 sw=4 fdc=3

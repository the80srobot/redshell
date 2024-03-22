" Notes: To check the meaning of the highlight groups, :help 'highlight'

set background=light

highlight clear
if exists("syntax_on")
    syntax reset
endif
let g:colors_name="t8rlight"

"----------------------------------------------------------------
" General settings                                              |
"----------------------------------------------------------------
"----------------------------------------------------------------
" Syntax group   | Foreground    | Background    | Style        |
"----------------------------------------------------------------

" --------------------------------
" COLORS
" --------------------------------
" t8r green: 0035
" t8r blue: 0039
" t8r deepblue: 0025
" t8r black: 0016
" t8r white: 0231
" t8r gold: 0220
" t8r red: 0197
" t8r dark: 0237
" t8r light: 0253
" t8r orange: 0202
" t8r deepred: 0160

" --------------------------------
" Editor settings
" --------------------------------
hi Normal          ctermfg=0016    ctermbg=0231    cterm=none
hi Cursor          ctermfg=none    ctermbg=none    cterm=none
hi CursorLine      ctermfg=none    ctermbg=none    cterm=none
hi LineNr          ctermfg=none    ctermbg=none    cterm=none
hi CursorLineNR    ctermfg=none    ctermbg=none    cterm=none

" -----------------
" - Number column -
" -----------------
hi CursorColumn    ctermfg=none    ctermbg=none    cterm=none
hi FoldColumn      ctermfg=none    ctermbg=none    cterm=none
hi SignColumn      ctermfg=none    ctermbg=none    cterm=none
hi Folded          ctermfg=none    ctermbg=none    cterm=none

" -------------------------
" - Window/Tab delimiters - 
" -------------------------
hi VertSplit       ctermfg=none    ctermbg=none    cterm=none
hi ColorColumn     ctermfg=0160    ctermbg=0160    cterm=none
hi TabLine         ctermfg=none    ctermbg=none    cterm=none
hi TabLineFill     ctermfg=none    ctermbg=none    cterm=none
hi TabLineSel      ctermfg=none    ctermbg=none    cterm=none

" -------------------------------
" - File Navigation / Searching -
" -------------------------------
hi Directory       ctermfg=none    ctermbg=none    cterm=none
hi Search          ctermfg=none    ctermbg=none    cterm=none
hi IncSearch       ctermfg=none    ctermbg=none    cterm=none

" -----------------
" - Prompt/Status -
" -----------------
hi StatusLine      ctermfg=none    ctermbg=none    cterm=none
hi StatusLineNC    ctermfg=none    ctermbg=none    cterm=none
hi WildMenu        ctermfg=none    ctermbg=none    cterm=none
hi Question        ctermfg=none    ctermbg=none    cterm=none
hi Title           ctermfg=none    ctermbg=none    cterm=none
hi ModeMsg         ctermfg=none    ctermbg=none    cterm=none
hi MoreMsg         ctermfg=none    ctermbg=none    cterm=none

" --------------
" - Visual aid -
" --------------
hi MatchParen      ctermfg=0231    ctermbg=0220    cterm=none
hi Visual          ctermfg=0231    ctermbg=0025    cterm=none
hi VisualNOS       ctermfg=none    ctermbg=none    cterm=none
hi NonText         ctermfg=none    ctermbg=none    cterm=none

hi Todo            ctermfg=none    ctermbg=none    cterm=bold
hi Underlined      ctermfg=none    ctermbg=none    cterm=none
hi Error           ctermfg=none    ctermbg=0160    cterm=underline
hi ErrorMsg        ctermfg=none    ctermbg=0160    cterm=underline
hi WarningMsg      ctermfg=none    ctermbg=0220    cterm=underline
hi Ignore          ctermfg=none    ctermbg=none    cterm=none
hi SpecialKey      ctermfg=none    ctermbg=none    cterm=none

" --------------------------------
" Variable types
" --------------------------------
hi Constant        ctermfg=0035    ctermbg=none    cterm=none
hi String          ctermfg=0025    ctermbg=none    cterm=none
hi StringDelimiter ctermfg=none    ctermbg=none    cterm=none
hi Character       ctermfg=0220    ctermbg=none    cterm=none
hi Number          ctermfg=0035    ctermbg=none    cterm=none
hi Boolean         ctermfg=0035    ctermbg=none    cterm=none
hi Float           ctermfg=0035    ctermbg=none    cterm=none

hi Identifier      ctermfg=0025    ctermbg=none    cterm=bold
hi Function        ctermfg=0160    ctermbg=none    cterm=none

" --------------------------------
" Language constructs
" --------------------------------
hi Statement       ctermfg=0202    ctermbg=none    cterm=bold
hi Conditional     ctermfg=none    ctermbg=none    cterm=bold
hi Repeat          ctermfg=none    ctermbg=none    cterm=bold
hi Label           ctermfg=none    ctermbg=none    cterm=none
hi Operator        ctermfg=none    ctermbg=none    cterm=none
hi Keyword         ctermfg=0202    ctermbg=none    cterm=bold
hi Exception       ctermfg=0160    ctermbg=none    cterm=bold
hi Comment         ctermfg=0246    ctermbg=none    cterm=none

hi Special         ctermfg=0202    ctermbg=none    cterm=none
hi SpecialChar     ctermfg=none    ctermbg=none    cterm=none
hi Tag             ctermfg=none    ctermbg=none    cterm=none
hi Delimiter       ctermfg=none    ctermbg=none    cterm=none
hi SpecialComment  ctermfg=none    ctermbg=none    cterm=none
hi Debug           ctermfg=none    ctermbg=none    cterm=none

" ----------
" - C like -
" ----------
hi PreProc         ctermfg=none    ctermbg=none    cterm=none
hi Include         ctermfg=0202    ctermbg=none    cterm=bold
hi Define          ctermfg=0160    ctermbg=none    cterm=none
hi Macro           ctermfg=none    ctermbg=none    cterm=none
hi PreCondit       ctermfg=none    ctermbg=none    cterm=none

hi Type            ctermfg=none    ctermbg=none    cterm=none
hi StorageClass    ctermfg=none    ctermbg=none    cterm=none
hi Structure       ctermfg=none    ctermbg=none    cterm=none
hi Typedef         ctermfg=none    ctermbg=none    cterm=none

" --------------------------------
" Diff
" --------------------------------
hi DiffAdd         ctermfg=none    ctermbg=none    cterm=none
hi DiffChange      ctermfg=none    ctermbg=none    cterm=none
hi DiffDelete      ctermfg=none    ctermbg=none    cterm=none
hi DiffText        ctermfg=none    ctermbg=none    cterm=none

" --------------------------------
" Completion menu
" --------------------------------
hi Pmenu           ctermfg=none    ctermbg=none    cterm=none
hi PmenuSel        ctermfg=none    ctermbg=none    cterm=none
hi PmenuSbar       ctermfg=none    ctermbg=none    cterm=none
hi PmenuThumb      ctermfg=none    ctermbg=none    cterm=none

" --------------------------------
" Spelling
" --------------------------------
hi SpellBad        ctermfg=none    ctermbg=none    cterm=none
hi SpellCap        ctermfg=none    ctermbg=none    cterm=none
hi SpellLocal      ctermfg=none    ctermbg=none    cterm=none
hi SpellRare       ctermfg=none    ctermbg=none    cterm=none

" --------------------------------
" Python
" --------------------------------
hi pythonFunction   ctermfg=0160  ctermbg=none  cterm=bold
hi pythonBuiltin    ctermfg=0035  ctermbg=none  cterm=none
hi pythonDecorator  ctermfg=none  ctermbg=none  cterm=bold
hi pythonSpaceError ctermfg=none  ctermbg=0253  cterm=none
hi pythonImport     ctermfg=0202  ctermbg=none  cterm=bold
hi pythonException  ctermfg=none  ctermbg=none  cterm=bold
hi pythonOperator   ctermfg=none  ctermbg=none  cterm=bold


" --------------------------------
" XML
" --------------------------------
hi xmlTag           ctermfg=0160  ctermbg=none  cterm=none
hi xmlTagName       ctermfg=0160  ctermbg=none  cterm=none
hi xmlEndTag        ctermfg=0160  ctermbg=none  cterm=none
hi xmlAttrib        ctermfg=none  ctermbg=none  cterm=bold

" --------------------------------
" Markdown
" --------------------------------
hi htmlH1           ctermfg=0160  ctermbg=none  cterm=bold
hi mkdString        ctermfg=none  ctermbg=none  cterm=none 
hi mkdCode          ctermfg=0035  ctermbg=none  cterm=none 
hi mkdCodeStart     ctermfg=none  ctermbg=none  cterm=none 
hi mkdCodeEnd       ctermfg=none  ctermbg=none  cterm=none 
hi mkdFootnote      ctermfg=none  ctermbg=none  cterm=none 
hi mkdBlockquote    ctermfg=none  ctermbg=none  cterm=none 
hi mkdListItem      ctermfg=0160  ctermbg=none  cterm=none 
hi mkdRule          ctermfg=none  ctermbg=none  cterm=none 
hi mkdLineBreak     ctermfg=none  ctermbg=none  cterm=none 
hi mkdFootnotes     ctermfg=none  ctermbg=none  cterm=none 
hi mkdLink          ctermfg=0025  ctermbg=none  cterm=none
hi mkdURL           ctermfg=0025  ctermbg=none  cterm=underline
hi mkdInlineURL     ctermfg=0025  ctermbg=none  cterm=underline 
hi mkdID            ctermfg=none  ctermbg=none  cterm=none 
hi mkdLinkDef       ctermfg=none  ctermbg=none  cterm=none
hi mkdLinkDefTarget ctermfg=0025  ctermbg=none  cterm=underline 
hi mkdLinkTitle     ctermfg=none  ctermbg=none  cterm=bold
hi mkdDelimiter     ctermfg=none  ctermbg=none  cterm=none 


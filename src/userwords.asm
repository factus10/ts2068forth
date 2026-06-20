; =============================================================================
; userwords.asm — Additional utility words
;
; DUMP, FILL, ERASE, .S, WORDS, .", .( and other conveniences.
; =============================================================================

; ============================================================ FILL ===========
; FILL  ( addr n byte -- )  Fill n bytes at addr with byte
W_FILL: LFA_EMIT
_LINK = W_FILL
        db  4, "FIL", 'L'|0x80
FILL:   dw  FILL_CODE
FILL_CODE:
    ; TOS=byte(HL), NOS=n, 3rd=addr
    ld  a, l            ; A = fill byte
    pop  bc             ; BC = n
    pop  hl             ; HL = addr
    ld  d, a            ; save fill byte
    ld  a, b : or  c
    jr  z, .fill_done
    ld  (hl), d         ; store first byte
    ld  a, b : or  c
    dec bc              ; n-1 remaining
    ld  a, b : or  c
    jr  z, .fill_done
    ld  d, h : ld  e, l
    inc de              ; DE = addr+1
    ldir                ; copy n-1 bytes
.fill_done:
    POP_TOS : jp  FORTH_NEXT

; ============================================================ ERASE ==========
; ERASE  ( addr n -- )  Fill n bytes with zero
W_ERASE: LFA_EMIT
_LINK = W_ERASE
         db  5, "ERAS", 'E'|0x80
ERASE:   dw  ERASE_CODE
ERASE_CODE:
    ; TOS=n(HL), NOS=addr
    ld  b, h : ld  c, l ; BC = n
    pop  hl             ; HL = addr
    ld  a, b : or  c
    jr  z, .erase_done
    ld  (hl), 0
    dec bc
    ld  a, b : or  c
    jr  z, .erase_done
    ld  d, h : ld  e, l
    inc de
    ldir
.erase_done:
    POP_TOS : jp  FORTH_NEXT

; ============================================================ DUMP ===========
; DUMP  ( addr n -- )  Hex dump n bytes starting at addr
W_DUMP: LFA_EMIT
_LINK = W_DUMP
        db  4, "DUM", 'P'|0x80
DUMP:   dw  DUMP_CODE
DUMP_CODE:
    ; TOS=n(HL), NOS=addr
    ld  b, h : ld  c, l ; BC = count
    pop  hl             ; HL = addr
    ld  a, b : or  c
    jr  z, .dump_done
.dump_line:
    ; Print address
    push bc             ; save count
    push hl             ; save addr
    ld  a, h
    call _PRINT_HEX
    ld  a, l
    call _PRINT_HEX
    ld  a, ':' : rst 0x10
    ld  a, 32  : rst 0x10
    pop  hl             ; restore addr
    pop  bc             ; restore count
    ; Print up to 8 bytes
    ld  d, 8            ; bytes per line
.dump_byte:
    ld  a, b : or  c
    jr  z, .dump_nl
    ld  a, (hl)
    push hl : push bc : push de
    call _PRINT_HEX
    ld  a, 32 : rst 0x10
    pop  de : pop  bc : pop  hl
    inc hl
    dec bc
    dec d
    jr  nz, .dump_byte
.dump_nl:
    ld  a, 13 : rst 0x10
    ld  a, b : or  c
    jr  nz, .dump_line
.dump_done:
    POP_TOS : jp  FORTH_NEXT

; Print A as 2-digit hex
_PRINT_HEX:
    push af
    rrca : rrca : rrca : rrca
    call _PRINT_NIBBLE
    pop  af
_PRINT_NIBBLE:
    and 0x0F
    cp  10
    jr  c, .ph_dig
    add a, 'A' - 10 - '0'
.ph_dig:
    add a, '0'
    rst 0x10
    ret

; ============================================================ .S =============
; .S  ( -- )  Non-destructively print stack contents
W_DOTS: LFA_EMIT
_LINK = W_DOTS
        db  2, ".", 'S'|0x80
DOTS:   dw  DOTS_CODE
DOTS_CODE:
    ; Print stack depth, then all values
    ; TOS is in HL, rest is on SP
    push hl             ; save TOS
    ; Calculate depth: (PS_TOP - SP) / 2
    ld  hl, 0 : add hl, sp
    ld  de, hl          ; DE = current SP (after pushing TOS)
    ld  hl, PS_TOP
    or  a
    sbc hl, de          ; HL = PS_TOP - SP = bytes on stack
    srl h : rr  l       ; HL = depth (items on stack)
    ; Print depth in angle brackets
    ld  a, '<' : rst 0x10
    push de             ; save SP value
    ld  a, l
    add a, '0'          ; simple single-digit depth (0-9)
    cp  '9'+1
    jr  c, .ds_dig
    ld  a, '+'          ; more than 9 items
.ds_dig:
    rst 0x10
    ld  a, '>' : rst 0x10
    ld  a, 32  : rst 0x10
    pop  de             ; DE = saved SP
    pop  hl             ; restore TOS
    ; Now print all items bottom-to-top
    ; Bottom of stack is at PS_TOP-2, top is at SP
    push hl             ; save TOS again
    ld  hl, PS_TOP - 2  ; start from bottom
.ds_loop:
    ; Compare HL with DE (current SP): if HL < DE, we're past the stack
    push hl : push de
    or  a
    sbc hl, de
    pop  de : pop  hl
    jr  c, .ds_tos      ; HL < DE: done with stack items
    ; Print value at (HL), (HL+1)
    push de : push hl
    ld  e, (hl) : dec hl : ld  d, (hl)
    ; DE = value (little-endian: low at lower addr)
    ; Print as signed decimal using . (DOT)
    ; Simpler: just print hex
    ld  a, d
    call _PRINT_HEX
    ld  a, e
    call _PRINT_HEX
    ld  a, 32 : rst 0x10
    pop  hl : pop  de
    dec hl : dec hl     ; next item down
    jr  .ds_loop
.ds_tos:
    ; Print TOS (which we saved)
    pop  hl             ; restore TOS
    push hl
    ld  a, h
    call _PRINT_HEX
    ld  a, l
    call _PRINT_HEX
    ld  a, 32 : rst 0x10
    pop  hl             ; restore TOS
    jp  FORTH_NEXT

; ============================================================ WORDS ==========
; WORDS  ( -- )  Alias for VLIST
W_WORDS: LFA_EMIT
_LINK = W_WORDS
         db  5, "WORD", 'S'|0x80
WORDS:   dw  VLIST_CODE       ; same code as VLIST

; ============================================================ ." =============
; ."  ( -- )  Print inline string (compile-time only)
; In compile mode: scan string until ", compile as LIT addr LIT len TYPE
; In interpret mode: just print directly
W_DOTQUOTE: LFA_EMIT
_LINK = W_DOTQUOTE
            db  F_IMM | 2, ".", '"'|0x80
DOTQUOTE:   dw  DOTQUOTE_CODE
DOTQUOTE_CODE:
    ; Scan input for closing "
    ld  hl, (USER_START + U_TIB)
    ld  de, (USER_START + U_IN)
    add hl, de          ; HL = current input position
    ; Skip leading space after ."
    ld  a, (hl)
    cp  32
    jr  nz, .dq_nospc
    inc hl
.dq_nospc:
    ; HL = start of string
    push hl             ; save string start
    ld  de, 0           ; DE = length counter
.dq_scan:
    ld  a, (hl)
    cp  '"' : jr  z, .dq_found
    or  a   : jr  z, .dq_found
    cp  13  : jr  z, .dq_found
    inc hl : inc de
    jr  .dq_scan
.dq_found:
    ; Update >IN
    inc hl              ; skip past closing "
    push de             ; save length
    push hl             ; save position after "
    ld  de, (USER_START + U_TIB)
    or  a
    sbc hl, de
    ld  (USER_START + U_IN), hl
    pop  hl             ; discard
    pop  de             ; DE = length
    pop  hl             ; HL = string start
    ; Check STATE
    ld  a, (USER_START + U_STATE)
    or  a
    jr  nz, .dq_compile
    ; Interpret mode: just print
    ld  b, d : ld  c, e ; BC = length
    ld  a, b : or  c
    jr  z, .dq_done
.dq_print:
    ld  a, (hl)
    rst 0x10
    inc hl
    dec bc
    ld  a, b : or  c
    jr  nz, .dq_print
.dq_done:
    jp  FORTH_NEXT
.dq_compile:
    ; Compile mode: compile as inline string with (.")
    ; Compile (."): LIT, addr, LIT, len, TYPE
    ; Actually use the simpler approach: compile count + string inline
    ; then at runtime skip past it after printing.
    ; For now, just do interpret-mode printing even in compile mode
    ; (IMMEDIATE word, so it executes during compilation)
    ld  b, d : ld  c, e
    ld  a, b : or  c
    jr  z, .dq_done
    jr  .dq_print

; ============================================================ .( =============
; .(  ( -- )  Print inline string immediately (even in compile mode)
W_DOTPAREN: LFA_EMIT
_LINK = W_DOTPAREN
            db  F_IMM | 2, ".", '('|0x80
DOTPAREN:   dw  DOTPAREN_CODE
DOTPAREN_CODE:
    ; Scan input until )
    ld  hl, (USER_START + U_TIB)
    ld  de, (USER_START + U_IN)
    add hl, de
    ; Skip leading space
    ld  a, (hl)
    cp  32
    jr  nz, .dp_nospc
    inc hl
.dp_nospc:
.dp_loop:
    ld  a, (hl)
    cp  ')' : jr  z, .dp_end
    or  a   : jr  z, .dp_end
    cp  13  : jr  z, .dp_end
    rst 0x10
    inc hl
    jr  .dp_loop
.dp_end:
    inc hl              ; skip past )
    ld  de, (USER_START + U_TIB)
    or  a
    sbc hl, de
    ld  (USER_START + U_IN), hl
    jp  FORTH_NEXT

; ============================================================ EXPECT =========
; EXPECT  ( addr n -- )  Read n chars from keyboard into addr
W_EXPECT: LFA_EMIT
_LINK = W_EXPECT
          db  6, "EXPEC", 'T'|0x80
EXPECT:   dw  EXPECT_CODE
EXPECT_CODE:
    ; TOS=n(HL), NOS=addr
    ld  b, l            ; B = max chars
    pop  hl             ; HL = buffer address
    ld  c, 0            ; C = chars received
.exp_loop:
    ld  a, c : cp  b
    jr  nc, .exp_done   ; buffer full
    push bc : push hl
    halt                ; wait for interrupt (keyboard scan)
    ld  hl, SYSVAR_FLAGS
    bit 5, (hl)
    jr  z, .exp_nokey
    res 5, (hl)
    ld  a, (SYSVAR_LASTK)
    pop  hl : pop  bc
    cp  13 : jr  z, .exp_done   ; CR = end input
    cp  8  : jr  z, .exp_bs     ; backspace
    cp  32 : jr  c, .exp_loop   ; ignore other control chars
    ; Store char and echo
    ld  (hl), a
    inc hl : inc c
    rst 0x10            ; echo
    jr  .exp_loop
.exp_nokey:
    pop  hl : pop  bc
    jr  .exp_loop
.exp_bs:
    ld  a, c
    or  a
    jr  z, .exp_loop    ; nothing to delete
    dec hl : dec c
    ld  a, 8  : rst 0x10
    ld  a, 32 : rst 0x10
    ld  a, 8  : rst 0x10
    jr  .exp_loop
.exp_done:
    ; Pad rest with spaces
    ld  a, c : cp  b
    jr  nc, .exp_fin
    ld  (hl), 32
    inc hl : inc c
    jr  .exp_done
.exp_fin:
    ld  a, 13 : rst 0x10
    POP_TOS : jp  FORTH_NEXT

; ============================================================ DOES> ==========
; DOES>  ( -- )  Define runtime behavior for words created by a defining word
; Compile-time: compile (;CODE) then switch to compiling the DOES> body
; Runtime of the created word: push PFA, then execute the DOES> thread
W_DOES: LFA_EMIT
_LINK = W_DOES
        db  F_IMM | 5, "DOES", '>'|0x80
DOES:   dw  DOES_CODE
DOES_CODE:
    ; DOES> is IMMEDIATE: it runs while the defining word (e.g. MATERIAL) is
    ; being compiled. It compiles two things into the defining word's thread,
    ; right where DOES> appears:
    ;   1. (;CODE)  — a runtime word that, when the defining word later RUNS,
    ;                 patches the just-CREATE'd child word's CFA to point at the
    ;                 CALL below, then exits the defining word (;S).
    ;   2. CALL FORTH_DODOES  — machine code. The child word's CFA is patched to
    ;                 point here; running the child executes this CALL, which
    ;                 hands the does-thread (the words compiled after DOES>) to
    ;                 FORTH_DODOES with the child PFA on the stack.
    ; Compilation then continues with the DOES> body; the defining word's ;
    ; appends the terminating ;S that the does-thread runs to.
    ld  de, (USER_START + U_DP)
    ; compile (;CODE) CFA
    ld  a, PSEMICODE & 0xFF : ld  (de), a : inc de
    ld  a, PSEMICODE >> 8   : ld  (de), a : inc de
    ; compile CALL FORTH_DODOES  (Z80 machine code: CD lo hi)
    ld  a, 0xCD                : ld  (de), a : inc de
    ld  a, FORTH_DODOES & 0xFF : ld  (de), a : inc de
    ld  a, FORTH_DODOES >> 8   : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    jp  FORTH_NEXT          ; stay in compile mode; DOES> body compiles next

; (;CODE) runtime — headerless internal word compiled by DOES>. When the
; defining word runs, this patches the latest (just-CREATE'd) child word's CFA
; to point at the CALL FORTH_DODOES that follows it, then exits (like ;S).
PSEMICODE:  dw  PSEMICODE_CODE
PSEMICODE_CODE:
    push hl                 ; save TOS
    ; HL = child CFA  (from the latest word in the CURRENT vocabulary)
    ld  hl, (USER_START + U_CURRENT)
    ld  e, (hl) : inc hl : ld  d, (hl)   ; DE = NFA of latest word
    ld  a, (de) : and 0x1F               ; A = name length
    ld  l, a : ld  h, 0
    inc de                               ; DE = NFA+1 (first name char)
    add hl, de                           ; HL = CFA = NFA+1+namelen
    ; patch child CFA = FORTH_IP (= address of the CALL FORTH_DODOES that
    ; immediately follows this (;CODE) in the defining word's thread)
    ld  de, (FORTH_IP)
    ld  (hl), e : inc hl : ld  (hl), d
    ; exit the defining word: ;S (pop IP from return stack)
    RPOP_HL                 ; HL = caller IP (destroys DE)
    ld  (FORTH_IP), hl
    pop hl                  ; restore TOS
    jp  FORTH_NEXT

; ============================================================ FORGET =========
; FORGET  ( -- )  Remove a word and everything after it from dictionary
W_FORGET_W: LFA_EMIT
_LINK = W_FORGET_W
             db  6, "FORGE", 'T'|0x80
FORGET_W:    dw  FORGET_W_CODE
FORGET_W_CODE:
    ; Parse next word, find it, restore DP and vocab to before it
    PUSH_TOS
    ld  hl, 32
    call _MC_WORD           ; HL = HERE (counted string)
    ld  a, (hl)
    and 0x1F
    jr  z, .fgt_empty
    ; Search for word
    ld  (MF_HERE), hl
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    call _DICT_SEARCH       ; Z=not found, else HL=CFA, A=count
    jr  z, .fgt_notfound
    ; Found. HL = CFA. NFA = CFA - name_len - 1. LFA = NFA - 2.
    ; We need NFA to find the LFA, then set CURRENT vocab and DP.
    ; Go backwards from CFA: the count byte is just before the name.
    ; Search backwards for the count byte (has high bit characteristics)
    ; Easier: walk from start. Or compute:
    ;   count byte is at CFA - name_len - 1
    ;   But we don't have name_len without re-reading...
    ; Use a different approach: we still have (MF_HERE) = our search term
    ; Re-search to find NFA directly:
    push hl             ; save CFA
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    ; DE = NFA of most recent word. Walk until CFA matches.
.fgt_walk:
    ld  a, d : or  e
    jr  z, .fgt_notfound2
    ; Compute CFA of this NFA (DE)
    push de             ; save NFA
    ld  a, (de)
    and 0x1F
    inc a               ; +1 for count byte
    ld  c, a : ld  b, 0
    ex  de, hl
    add hl, bc
    ex  de, hl          ; DE = CFA of this word
    pop  hl             ; HL = NFA
    ; Compare with saved CFA
    ex  (sp), hl        ; swap: (SP)=NFA, HL=saved CFA
    or  a
    sbc hl, de
    ex  (sp), hl        ; restore: (SP)=saved CFA, HL=NFA
    jr  z, .fgt_found_nfa
    ; Follow LFA chain
    dec hl : dec hl     ; HL = LFA addr
    ld  e, (hl) : inc hl : ld  d, (hl)
    ld  a, d : or  e
    jr  z, .fgt_notfound2
    inc de : inc de     ; NFA of prev word
    jr  .fgt_walk
.fgt_found_nfa:
    ; HL = NFA of found word. LFA = NFA - 2.
    pop  de             ; discard saved CFA
    ; Check FENCE
    dec hl : dec hl     ; HL = LFA address of found word
    ld  de, (USER_START + U_FENCE)
    push hl
    or  a
    sbc hl, de          ; HL - FENCE: if HL < FENCE, protected
    pop  hl
    jr  c, .fgt_protected
    ; Set DP to LFA address (everything from LFA onward is freed)
    ld  (USER_START + U_DP), hl
    ; Update CURRENT vocab: follow LFA to get previous word's NFA
    ld  e, (hl) : inc hl : ld  d, (hl)
    ; DE = LFA of previous word. NFA = LFA + 2.
    inc de : inc de
    ld  hl, (USER_START + U_CURRENT)
    ld  (hl), e : inc hl : ld  (hl), d
    POP_TOS : jp  FORTH_NEXT
.fgt_protected:
    ld  hl, _STR_PROT
    call _PRINT_STR
    POP_TOS : jp  FORTH_NEXT
.fgt_notfound2:
    pop  de             ; clean stack
.fgt_notfound:
    ld  hl, _STR_ERR
    call _PRINT_STR
.fgt_empty:
    POP_TOS : jp  FORTH_NEXT

_STR_PROT: db " PROTECTED", 0

; ============================================================ Screen Editor ===
; Simple line editor for block screens.
; A screen = 1024 bytes = 16 lines × 64 chars.
; SCR holds the current screen number.
; R# (U_R_HASH) holds the current editing line (0-15).

; LINE  ( n blk -- addr )  Address of line n in block blk
W_LINE: LFA_EMIT
_LINK = W_LINE
        db  4, "LIN", 'E'|0x80
LINE:   dw  LINE_CODE
LINE_CODE:
    ; TOS=blk(HL), NOS=n
    call _BUF_FIND
    jr  z, .line_have
    call _BUF_ASSIGN
.line_have:
    ; DE = buffer data address
    pop  hl             ; HL = line number n
    ; addr = buffer + n * 64
    ld  b, h : ld  c, l ; BC = n
    ld  hl, 0
    ld  a, c
    rlca : rlca : rlca : rlca : rlca : rlca  ; * 64
    ld  l, a
    and 0xC0 : ld  l, a  ; mask low bits (only works for n < 4)
    ; Better: n * 64 = shift left 6
    ld  hl, 0
    ld  l, c            ; HL = n
    add hl, hl          ; *2
    add hl, hl          ; *4
    add hl, hl          ; *8
    add hl, hl          ; *16
    add hl, hl          ; *32
    add hl, hl          ; *64
    add hl, de          ; HL = buffer + n*64
    jp  FORTH_NEXT

; T  ( n -- )  Type (display) line n of current screen
W_ED_T: LFA_EMIT
_LINK = W_ED_T
        db  1, 'T'|0x80
ED_T:   dw  ED_T_CODE
ED_T_CODE:
    ; Get line address
    ld  (USER_START + U_R_HASH), hl  ; set R# to this line
    PUSH_TOS
    ld  hl, (USER_START + U_SCR)    ; blk = SCR
    call LINE_CODE      ; HL = line address
    ; Print 64 chars
    ld  b, 64
.edt_print:
    ld  a, (hl)
    or  a
    jr  nz, .edt_vis
    ld  a, 32
.edt_vis:
    cp  32 : jr  nc, .edt_ok
    ld  a, 32
.edt_ok:
    rst 0x10
    inc hl
    djnz .edt_print
    ld  a, 13 : rst 0x10
    POP_TOS : jp  FORTH_NEXT

; P  ( n -- )  Put: replace line n of current screen with text from TIB
; Usage: P 3  (then type the replacement text)
W_ED_P: LFA_EMIT
_LINK = W_ED_P
        db  1, 'P'|0x80
ED_P:   dw  ED_P_CODE
ED_P_CODE:
    ; Get line address
    ld  (USER_START + U_R_HASH), hl
    PUSH_TOS
    ld  hl, (USER_START + U_SCR)
    call LINE_CODE      ; HL = line address
    ; Read input from TIB (rest of current input line after "P n ")
    ld  de, hl          ; DE = destination (line in buffer)
    ld  hl, (USER_START + U_TIB)
    ld  bc, (USER_START + U_IN)
    add hl, bc          ; HL = TIB + IN = remaining input
    ; Copy up to 64 chars, pad with spaces
    ld  b, 64
.edp_copy:
    ld  a, (hl)
    or  a : jr  z, .edp_pad
    cp  13 : jr  z, .edp_pad
    ld  (de), a
    inc hl : inc de
    dec b
    jr  nz, .edp_copy
    jr  .edp_done
.edp_pad:
    ld  a, 32
    ld  (de), a
    inc de
    dec b
    jr  nz, .edp_pad
.edp_done:
    ; Mark buffer as updated
    push hl
    ld  hl, BUF_START + 2
    set 0, (hl)
    ld  hl, BUF_START + BUF_ENTRY_SIZE + 2
    set 0, (hl)
    pop  hl
    ; Advance IN to end of input so interpreter doesn't re-parse
    ld  hl, 255
    ld  (USER_START + U_IN), hl
    POP_TOS : jp  FORTH_NEXT

; D  ( n -- )  Delete line n, scroll remaining lines up, blank last line
W_ED_D: LFA_EMIT
_LINK = W_ED_D
        db  1, 'D'|0x80
ED_D:   dw  ED_D_CODE
ED_D_CODE:
    ld  (USER_START + U_R_HASH), hl
    PUSH_TOS
    ld  hl, (USER_START + U_SCR)
    call LINE_CODE      ; HL = addr of line n
    ; Move lines n+1..15 up by 64 bytes
    ld  de, hl          ; DE = dest (line n)
    push de
    ld  bc, 64
    add hl, bc          ; HL = source (line n+1)
    ; Calculate bytes to move: (15 - n) * 64
    ; Simpler: just move from line n+1 to end of screen
    ld  a, (USER_START + U_R_HASH)
    ld  c, a
    ld  a, 15
    sub c               ; A = lines to move (15-n)
    jr  z, .edd_blank   ; deleting last line, just blank it
    ld  b, 0
    ld  c, a
    ; BC = lines to move. Multiply by 64.
    sla c : rl  b       ; *2
    sla c : rl  b       ; *4
    sla c : rl  b       ; *8
    sla c : rl  b       ; *16
    sla c : rl  b       ; *32
    sla c : rl  b       ; *64
    ldir
.edd_blank:
    ; Blank last line (DE points to it after LDIR, or line 15 if n=15)
    pop  hl             ; discard saved DE
    ; Blank from DE for 64 bytes
    ld  h, d : ld  l, e
    ld  (hl), 32
    ld  d, h : ld  e, l
    inc de
    ld  bc, 63
    ldir
    POP_TOS : jp  FORTH_NEXT

; I  ( n -- )  Insert blank line at n, scroll remaining lines down
W_ED_I: LFA_EMIT
_LINK = W_ED_I
        db  1, 'I'|0x80
ED_I:   dw  ED_I_CODE
ED_I_CODE:
    ld  (USER_START + U_R_HASH), hl
    PUSH_TOS
    ld  hl, (USER_START + U_SCR)
    call LINE_CODE      ; HL = addr of line n
    push hl             ; save line n addr
    ; Move lines n..14 down by 64 bytes (must copy backwards)
    ; Last line (15) is lost.
    ; Source = line 14 end-1, Dest = line 15 end-1
    ; Use LDDR for backward copy
    ld  a, (USER_START + U_R_HASH)
    ld  c, a
    ld  a, 15
    sub c
    jr  z, .edi_blank   ; inserting at line 15, just blank it
    ld  b, 0 : ld  c, a
    sla c : rl  b
    sla c : rl  b
    sla c : rl  b
    sla c : rl  b
    sla c : rl  b
    sla c : rl  b       ; BC = bytes to move
    ; Source end = line n addr + BC - 1
    pop  hl : push hl
    push bc
    add hl, bc
    dec hl              ; HL = source end
    ld  de, hl
    ld  bc, 64
    ex  de, hl
    add hl, bc          ; HL+64... no: dest = source + 64
    ex  de, hl          ; DE = dest end = source end + 64
    pop  bc
    lddr
.edi_blank:
    ; Blank line n
    pop  hl             ; HL = line n addr
    ld  (hl), 32
    ld  d, h : ld  e, l
    inc de
    ld  bc, 63
    ldir
    POP_TOS : jp  FORTH_NEXT

; CLEAR  ( blk -- )  Blank an entire screen
W_ED_CLEAR: LFA_EMIT
_LINK = W_ED_CLEAR
            db  5, "CLEA", 'R'|0x80
ED_CLEAR:   dw  ED_CLEAR_CODE
ED_CLEAR_CODE:
    ; TOS = blk#
    call _BUF_FIND
    jr  z, .ecl_have
    call _BUF_ASSIGN
.ecl_have:
    ; DE = data addr. Fill with spaces.
    ex  de, hl
    ld  (hl), 32
    ld  d, h : ld  e, l
    inc de
    ld  bc, BUF_DATA_SIZE - 1
    ldir
    POP_TOS : jp  FORTH_NEXT

; L  ( -- )  List current screen (SCR)
W_ED_L: LFA_EMIT
_LINK = W_ED_L
        db  1, 'L'|0x80
ED_L:   dw  ED_L_CODE
ED_L_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_SCR)
    jp  LIST_CODE

; ============================================================ More standard ===

; NEGATE  ( n -- -n )  Alias for MINUS
W_NEGATE: LFA_EMIT
_LINK = W_NEGATE
          db  6, "NEGAT", 'E'|0x80
NEGATE:   dw  MINUS_CODE       ; reuse MINUS

; TRUE  ( -- -1 )
W_TRUE: LFA_EMIT
_LINK = W_TRUE
        db  4, "TRU", 'E'|0x80
TRUE:   dw  TRUE_CODE
TRUE_CODE:
    PUSH_TOS
    ld  hl, 0xFFFF
    jp  FORTH_NEXT

; FALSE  ( -- 0 )
W_FALSE: LFA_EMIT
_LINK = W_FALSE
         db  5, "FALS", 'E'|0x80
FALSE:   dw  FALSE_CODE
FALSE_CODE:
    PUSH_TOS
    ld  hl, 0
    jp  FORTH_NEXT

; FREE  ( -- )  Print free dictionary space in bytes
W_FREE: LFA_EMIT
_LINK = W_FREE
        db  4, "FRE", 'E'|0x80
FREE:   dw  FREE_CODE
FREE_CODE:
    push hl                 ; save TOS
    ld  hl, DICT_RAM_END    ; $FFFF; free = ($FFFF-DP)+1 (avoids $10000 truncation)
    ld  de, (USER_START + U_DP)
    or  a
    sbc hl, de
    inc hl                  ; HL = free bytes
    call _PRINT_DECIMAL
    ld  hl, _STR_FREE
    call _PRINT_STR
    pop  hl                 ; restore TOS
    jp  FORTH_NEXT

; WITHIN  ( n lo hi -- flag )  True if lo <= n < hi
W_WITHIN: LFA_EMIT
_LINK = W_WITHIN
          db  6, "WITHI", 'N'|0x80
WITHIN:   dw  WITHIN_CODE
WITHIN_CODE:
    ; ( n lo hi -- flag )  True if lo <= n < hi (unsigned)
    ; Algorithm: (n - lo) u< (hi - lo)
    ; Entry: HL=hi, stack=[lo, n]
    pop  de             ; DE = lo
    or  a
    sbc hl, de          ; HL = hi - lo (range size)
    ld  b, h : ld  c, l ; BC = hi - lo
    pop  hl             ; HL = n
    or  a
    sbc hl, de          ; HL = n - lo  (DE still = lo)
    ; Test: is (n-lo) u< (hi-lo)?
    or  a
    sbc hl, bc          ; (n-lo) - (hi-lo)
    jr  c, .within_true ; carry → n-lo < hi-lo → in range
    ld  hl, 0
    jp  FORTH_NEXT
.within_true:
    ld  hl, 1
    jp  FORTH_NEXT

; MOVE  ( src dest len -- )  Copy len bytes, handles overlap correctly
W_MOVE: LFA_EMIT
_LINK = W_MOVE
        db  4, "MOV", 'E'|0x80
MOVE:   dw  MOVE_CODE
MOVE_CODE:
    ; ( src dest len -- )  Copy len bytes, handles overlap
    ; Entry: HL=len, stack=[dest, src]
    ld  b, h : ld  c, l ; BC = len
    pop  de             ; DE = dest
    pop  hl             ; HL = src
    ld  a, b : or  c
    jr  z, .move_done
    ; Check direction: if dest > src, copy backwards
    push hl             ; save src
    or  a
    sbc hl, de          ; src - dest
    pop  hl             ; restore src
    jr  nc, .move_fwd   ; src >= dest: forward is safe
    ; Backward copy: point to last bytes, then LDDR
    add hl, bc
    dec hl              ; HL = src + len - 1
    ex  de, hl          ; DE = src end, HL = dest
    add hl, bc
    dec hl              ; HL = dest + len - 1
    ex  de, hl          ; HL = src end, DE = dest end
    lddr
    jr  .move_done
.move_fwd:
    ldir
.move_done:
    POP_TOS : jp  FORTH_NEXT

; [COMPILE]  ( -- )  Compile the next word even if IMMEDIATE
W_BCOMPILE: LFA_EMIT
_LINK = W_BCOMPILE
            db  F_IMM | 9, "[COMPILE", ']'|0x80
BCOMPILE:   dw  BCOMPILE_CODE
BCOMPILE_CODE:
    ; Parse next word, find it, compile its CFA regardless of IMMEDIATE
    PUSH_TOS
    ld  hl, 32
    call _MC_WORD           ; HL = HERE (counted string)
    ld  a, (hl)
    and 0x1F
    jr  z, .bc_empty
    ; Search dictionary
    ld  (MF_HERE), hl
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    call _DICT_SEARCH
    jr  z, .bc_empty        ; not found
    ; HL = CFA. Compile it.
    ld  de, (USER_START + U_DP)
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
.bc_empty:
    POP_TOS : jp  FORTH_NEXT

; RECURSE  ( -- )  Compile a call to the current word being defined
W_RECURSE: LFA_EMIT
_LINK = W_RECURSE
           db  F_IMM | 7, "RECURS", 'E'|0x80
RECURSE:   dw  RECURSE_CODE
RECURSE_CODE:
    ; Get CFA of the word being defined (LATEST's CFA)
    push hl
    ld  hl, (USER_START + U_CURRENT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    ex  de, hl          ; HL = NFA of latest
    ld  a, (hl)
    and 0x1F
    inc hl              ; past count
    ld  d, 0 : ld  e, a
    add hl, de          ; HL = CFA
    ; Compile it
    ld  de, (USER_START + U_DP)
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    pop  hl
    jp  FORTH_NEXT

; '  ( -- cfa )  Tick: find next word, return its CFA
W_TICK: LFA_EMIT
_LINK = W_TICK
        db  1, 0x27|0x80       ; ' character
TICK:   dw  TICK_CODE
TICK_CODE:
    PUSH_TOS
    ld  hl, 32
    call _MC_WORD
    ld  a, (hl)
    and 0x1F
    jr  z, .tick_err
    ld  (MF_HERE), hl
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    call _DICT_SEARCH
    jr  z, .tick_err
    ; HL = CFA
    jp  FORTH_NEXT
.tick_err:
    ld  hl, _STR_ERR
    call _PRINT_STR
    jp  FORTH_ABORT

; [']  ( -- )  Compile-time tick: compile CFA of next word as literal
W_BTICK: LFA_EMIT
_LINK = W_BTICK
         db  F_IMM | 3, "['" , ']'|0x80
BTICK:   dw  BTICK_CODE
BTICK_CODE:
    ; Same as TICK but compile the CFA as a literal
    PUSH_TOS
    ld  hl, 32
    call _MC_WORD
    ld  a, (hl)
    and 0x1F
    jr  z, .bt_err
    ld  (MF_HERE), hl
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    call _DICT_SEARCH
    jr  z, .bt_err
    ; HL = CFA. Compile as LIT + CFA.
    ld  de, (USER_START + U_DP)
    ld  a, LIT & 0xFF : ld  (de), a : inc de
    ld  a, LIT >> 8   : ld  (de), a : inc de
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT
.bt_err:
    ld  hl, _STR_ERR
    call _PRINT_STR
    jp  FORTH_ABORT

; ============================================================ --> ===========
; -->  ( -- )  Continue interpretation on next screen
W_ARROW: LFA_EMIT
_LINK = W_ARROW
         db  3, "--", '>'|0x80
ARROW:   dw  ARROW_CODE
ARROW_CODE:
    ; Increment BLK, reset IN to 0
    ld  hl, (USER_START + U_BLK)
    inc hl
    ld  (USER_START + U_BLK), hl
    ld  hl, 0
    ld  (USER_START + U_IN), hl
    jp  FORTH_NEXT

; Label for COLD to find the last word's NFA
LAST_WORD_NFA EQU W_ARROW + 2

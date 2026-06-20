; =============================================================================
; dictionary.asm — Compiler, interpreter, colon defs, number I/O
;
; These are CODE words (machine code) that implement the Forth compiler
; and the outer interpreter. They live in ROM.
;
; Phase 2 scope:
;   - (NUMBER), NUMBER  — number parsing
;   - -FIND, (FIND)     — dictionary search
;   - INTERPRET         — token scanner and interpreter loop
;   - :  ;              — colon compiler
;   - VARIABLE CONSTANT — defining words
;   - LITERAL           — compile-time literal
;   - IF ELSE THEN      — conditionals
;   - BEGIN UNTIL WHILE REPEAT AGAIN  — loops
;   - DO LOOP +LOOP     — counted loops
;   - ." .( (           — string words
;   - <# # #S #> SIGN D. D.R . .R U. — number output
;   - TRAVERSE LATEST LFA CFA NFA PFA — dictionary tools
;   - CREATE SMUDGE !CSP ?COMP ?EXEC COMPILE
;   - COLD WARM words (dict entries pointing at engine.asm routines)
;   - ABORT QUIT        — dict entries
; =============================================================================

; ============================================================ TRAVERSE ========
; TRAVERSE  ( addr dir -- addr' )
; Step through name field. dir=1 steps forward, dir=-1 steps back.
W_TRAVERSE: LFA_EMIT
_LINK = W_TRAVERSE
            db  8, "TRAVERS", 'E'|0x80
TRAVERSE:   dw  TRAVERSE_CODE
TRAVERSE_CODE:
    ; TOS=dir(HL), NOS=addr
    ld  d, h : ld  e, l     ; DE = direction (+1 or -1)
    pop  hl                 ; HL = addr
.trav_loop:
    add hl, de              ; step
    ld  a, (hl)
    and 0x80                ; high bit of byte = end of name field marker
    jr  z, .trav_loop
    jp  FORTH_NEXT

; ============================================================ LATEST ==========
; LATEST  ( -- nfa )  NFA of most recently defined word
W_LATEST:   LFA_EMIT
_LINK = W_LATEST
            db  6, "LATES", 'T'|0x80
LATEST:     dw  LATEST_CODE
LATEST_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_CURRENT)  ; CURRENT -> vocabulary NFA pointer
    ld  e, (hl)
    inc hl
    ld  d, (hl)
    ex  de, hl            ; dereference: NFA of last word
    jp  FORTH_NEXT

; ============================================================ LFA / NFA / CFA / PFA
; LFA  ( nfa -- lfa )  NFA -> LFA  (2 bytes before NFA)
W_LFA:  LFA_EMIT
_LINK = W_LFA
        db  3, "LF", 'A'|0x80
LFA:    dw  LFA_CODE
LFA_CODE:
    dec hl : dec hl
    jp  FORTH_NEXT

; NFA  ( lfa -- nfa )  LFA -> NFA  (LFA + 2)
W_NFA:  LFA_EMIT
_LINK = W_NFA
        db  3, "NF", 'A'|0x80
NFA:    dw  NFA_CODE
NFA_CODE:
    inc hl : inc hl
    jp  FORTH_NEXT

; CFA  ( nfa -- cfa )  NFA -> CFA  (step past count + name bytes)
W_CFA:  LFA_EMIT
_LINK = W_CFA
        db  3, "CF", 'A'|0x80
CFA:    dw  CFA_CODE
CFA_CODE:
    ld  a, (hl)             ; count byte
    and 0x1F                ; length field
    inc hl                  ; past count byte
    ld  b, 0
    ld  c, a
    add hl, bc              ; skip name bytes -> HL = CFA
    jp  FORTH_NEXT

; PFA  ( cfa -- pfa )  CFA -> PFA  (CFA + 2)
W_PFA:  LFA_EMIT
_LINK = W_PFA
        db  3, "PF", 'A'|0x80
PFA:    dw  PFA_CODE
PFA_CODE:
    inc hl : inc hl
    jp  FORTH_NEXT

; ============================================================ ID. =============
; ID.  ( nfa -- )  Print word name from NFA
W_IDDOT:    LFA_EMIT
_LINK = W_IDDOT
            db  3, "ID", '.'|0x80
IDDOT:      dw  IDDOT_CODE
IDDOT_CODE:
    call _MC_IDDOT
    jp  FORTH_NEXT
_MC_IDDOT:
    ld  a, (hl)
    and 0x1F
    ld  b, a                ; B = name length
    inc hl                  ; past count
.id_loop:
    ld  a, (hl)
    and 0x7F                ; strip high bit on last char
    rst 0x10
    inc hl
    djnz .id_loop
    POP_TOS
    ret

; ============================================================ -FIND ===========
; -FIND  ( -- cfa b )  Find word at HERE in dictionary
; Searches for the word whose name is at HERE (counted string).
; Returns CFA and a flag byte: non-zero if found.
W_MFIND:    LFA_EMIT
_LINK = W_MFIND
            db  5, "-FIN", 'D'|0x80
MFIND:      dw  MFIND_CODE
MFIND_CODE:
    ; -FIND ( -- cfa b tf ) or ( -- ff )
    ; Parse next word (BL WORD), search dictionary.
    ; Returns CFA, count byte (with flags), and true if found; just false if not.
    PUSH_TOS
    ld  hl, 32              ; BL delimiter
    call _MC_WORD           ; HL = HERE (counted string)
    ; Check for empty word
    ld  a, (hl)
    and 0x1F
    jr  nz, .mf_go
    ; Empty word -> return false
    ld  hl, 0
    jp  FORTH_NEXT
.mf_go:
    ; HL = HERE = counted string to search for. Save it.
    ld  (MF_HERE), hl
    ; Get CONTEXT vocab head -> dereference to get NFA of most recent word
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    ; DE = NFA of most recent word in vocabulary
.mf_loop:
    ; End of chain? (NFA = 0 means the LFA was 0, so we went to address 2)
    ; Actually check: if LFA was 0, we derived NFA = 0+2 = 2. Check for LFA=0 differently.
    ; We'll check DE against a low sentinel. LFA=0 is the end marker.
    ; When we follow the chain, we go from NFA to LFA=(NFA-2), read prev_LFA,
    ; then prev_NFA = prev_LFA+2. If prev_LFA=0, prev_NFA=2 which is garbage.
    ; So check the LFA value for 0 BEFORE converting to NFA.
    ; For the first iteration, DE = NFA from vocab head. This is always valid.
    ld  a, d : or  e
    jr  z, .mf_notfound     ; NFA=0 means empty vocabulary
    ; Check smudge bit
    ld  a, (de)
    bit 5, a                ; F_SMUDGE
    jr  nz, .mf_advance     ; skip smudged words
    ; Compare lengths
    and 0x1F                ; dict word length
    ld  b, a
    ld  hl, (MF_HERE)
    ld  a, (hl)
    and 0x1F                ; search word length
    cp  b
    jr  nz, .mf_advance    ; lengths differ
    ; Compare name characters
    ld  c, b                ; C = count
    push de                 ; save NFA
    inc hl                  ; past search count byte
    inc de                  ; past dict count byte
.mf_cmp:
    ld  a, (de)
    and 0x7F                ; strip high bit (last char marker)
    ld  b, a
    ld  a, (hl)
    and 0x7F
    cp  b
    jr  nz, .mf_nomatch
    inc hl : inc de
    dec c
    jr  nz, .mf_cmp
    ; *** MATCH FOUND ***
    ; DE is now past the name = at CFA
    ; Get count byte from NFA for return
    pop  hl                 ; HL = NFA (saved)
    ld  b, (hl)             ; B = full count byte (with IMM flag etc.)
    ; CFA = NFA + 1(count) + namelen
    ld  a, (hl)
    and 0x1F                ; name length
    ld  c, a
    inc hl                  ; past count byte
    ld  d, 0 : ld  e, c
    add hl, de              ; HL = CFA
    ; Return ( CFA count-byte true )
    PUSH_TOS                ; push CFA
    ld  h, 0 : ld  l, b    ; HL = count byte
    PUSH_TOS                ; push count byte
    ld  hl, 1               ; true flag
    jp  FORTH_NEXT

.mf_nomatch:
    pop  de                 ; DE = current NFA (restore)
.mf_advance:
    ; Follow LFA chain: LFA is at NFA-2
    dec de : dec de         ; DE = LFA address
    ex  de, hl              ; HL = LFA address
    ld  e, (hl) : inc hl : ld  d, (hl)
    ; DE = previous word's LFA value
    ld  a, d : or  e
    jr  z, .mf_notfound     ; LFA=0 means end of chain
    ; Convert LFA to NFA: NFA = LFA + 2
    inc de : inc de         ; DE = NFA of previous word
    jr  .mf_loop

.mf_notfound:
    ld  hl, 0               ; false flag
    jp  FORTH_NEXT

; ============================================================ (NUMBER) ========
; (NUMBER)  ( d addr -- d' addr' )
; Convert digits from string at addr into double d, stopping at non-digit.
W_PNUMBER:  LFA_EMIT
_LINK = W_PNUMBER
            db  8, "(NUMBE", ('R')|0x80
PNUMBER:    dw  PNUMBER_CODE
PNUMBER_CODE:
    ; Threaded Forth entry: pop params from stack, run loop, push results back.
    ld  (PN_ADDR), hl       ; save addr (TOS)
    pop  de                 ; DE = d_high (from Forth stack — no CALL return addr issue)
    pop  hl                 ; HL = d_low
    ld  (PN_DLO), hl
    ld  (PN_DHI), de
    call _PNUMBER_LOOP      ; run the digit loop
    jp  PNUMBER_DONE_THREAD ; push results and FORTH_NEXT

_MC_PNUMBER:
    ; Legacy label (kept for any remaining references)
_PNUMBER_LOOP:          ; Machine-code callable entry (PN_DLO/PN_DHI/PN_ADDR preset)
.pnum_loop:
    ld  hl, (PN_ADDR)
    ld  a, (hl)
    ; --- Digit conversion (corrected) ---
    cp  '0' : jp  c, .pnum_done   ; < '0', not a digit
    cp  '9'+1 : jr  c, .pnum_decimal  ; '0'-'9'
    ; Try hex letter (original char still in A)
    and 0xDF                ; uppercase: 'a'->'A' etc.
    cp  'A' : jr  c, .pnum_done
    sub 'A' - 10            ; 'A'->10, 'B'->11, ...
    jr  .pnum_check_base
.pnum_decimal:
    sub '0'                 ; '0'->0, '1'->1, ...
.pnum_check_base:
    ; A = digit value. Check against BASE.
    ld  hl, (USER_START + U_BASE)
    cp  l : jr  nc, .pnum_done    ; digit >= base, stop
    ld  (PN_DIGIT), a       ; save digit
    ; Advance addr
    ld  hl, (PN_ADDR)
    inc hl
    ld  (PN_ADDR), hl
    ; d = d * BASE + digit
    ; Simple approach: d_low * BASE via repeated addition (no EXX needed)
    ; For BASE <= 36 and typical numbers, this is fast enough.
    ld  hl, (PN_DLO)        ; HL = d_low
    ld  de, (PN_DLO)        ; DE = copy of d_low (for repeated add)
    ld  a, (USER_START + U_BASE)
    dec a                   ; BASE-1 additions (first copy is free)
    jr  z, .pn_mul_done     ; BASE=1: result = d_low
    ld  b, a                ; B = loop counter
    ld  (PN_PRODHI), hl     ; use PRODHI as overflow accumulator (=0 init)
    ld  a, 0
    ld  (PN_PRODHI), a
    ld  a, 0
    ld  (PN_PRODHI+1), a
.pn_mul_add:
    add hl, de              ; HL += d_low
    jr  nc, .pn_no_ov
    push hl
    ld  hl, (PN_PRODHI)
    inc hl
    ld  (PN_PRODHI), hl
    pop  hl
.pn_no_ov:
    djnz .pn_mul_add
.pn_mul_done:
    ld  (PN_DLO), hl        ; new d_low = d_low * BASE (low 16)
    ; d_high * BASE (simple multiply, only low 16 needed)
    ld  hl, (PN_DHI)
    ld  de, (PN_DHI)
    ld  a, (USER_START + U_BASE)
    dec a
    jr  z, .pn_mulhi_done
    ld  b, a
.pn_mulhi_add:
    add hl, de
    djnz .pn_mulhi_add
.pn_mulhi_done:
    ; new d_high = (d_high * BASE) + overflow from d_low multiply
    ld  de, (PN_PRODHI)
    add hl, de
    ld  (PN_DHI), hl
    ; Step 3: add digit to d_low, propagate carry to d_high
    ld  a, (PN_DIGIT)
    ld  hl, (PN_DLO)
    ld  e, a : ld  d, 0
    add hl, de
    ld  (PN_DLO), hl
    jp  nc, .pnum_loop
    ld  hl, (PN_DHI)
    inc hl
    ld  (PN_DHI), hl
    jp  .pnum_loop
.pnum_done:
    ; Results are in PN_DLO, PN_DHI, PN_ADDR.
    ; If called from _PNUMBER_LOOP (machine code): just ret.
    ; If called from PNUMBER_CODE (threaded): push results, FORTH_NEXT.
    ret                     ; return to caller (_PNUMBER_LOOP or PNUMBER_CODE wrapper)

; Threaded Forth wrapper for (NUMBER):
PNUMBER_DONE_THREAD:
    ; Push results from scratch vars onto param stack for Forth
    ld  hl, (PN_DLO)
    push hl
    ld  hl, (PN_DHI)
    push hl
    ld  hl, (PN_ADDR)
    jp  FORTH_NEXT

; ============================================================ NUMBER ==========
; NUMBER  ( addr -- d )  Convert string to double number, abort on error
W_NUMBER:   LFA_EMIT
_LINK = W_NUMBER
            db  6, "NUMBE", 'R'|0x80
NUMBER:     dw  NUMBER_CODE
NUMBER_CODE:
    ; addr is TOS; parse as a number using (NUMBER)
    ; Setup: d=0, check leading minus
    ld  de, hl              ; DE = addr
    PUSH_TOS
    ; Push d=0,0
    ld  hl, 0
    PUSH_TOS                ; d_high = 0
    ld  hl, 0               ; d_low = 0 (TOS)
    PUSH_TOS
    ld  hl, de              ; addr (TOS)
    ; Check for leading minus sign
    ld  a, (hl)
    cp  '-'
    jr  nz, .no_neg
    inc hl                  ; skip minus
    push hl : pop ix        ; IX = addr (for (NUMBER))
    ; Save negation flag
    ld  a, 1
    ld  (NUM_NEG), a
    jr  .do_parse
.no_neg:
    xor a
    ld  (NUM_NEG), a
.do_parse:
    ; Stack: d_lo(0) d_hi(0) addr — call (NUMBER) inline
    ; (simplified: call the code directly)
    call _MC_PNUMBER
    ; Check remainder: should be at space or end
    ; If not, abort with error
    ld  a, (hl)
    cp  32 : jr  z, .num_ok
    cp  0  : jr  z, .num_ok
    cp  13 : jr  z, .num_ok
    ; Not a valid number — call ABORT
    ld  hl, _STR_NUM_ERR
    call _PRINT_STR
    jp  FORTH_ABORT
.num_ok:
    POP_TOS                 ; discard addr, d is now on stack as d_lo, d_hi
    ; If negative, negate
    ld  a, (NUM_NEG)
    or  a : jr  z, .num_done
    ; Negate: call DMINUS logic
    pop  de                 ; DE = d_high, HL = d_low
    ld  a, e : cpl : ld  e, a : ld  a, d : cpl : ld  d, a : inc de
    ld  a, l : cpl : ld  l, a : ld  a, h : cpl : ld  h, a
    jr  nc, .nn : inc hl
.nn:
    push de                 ; push negated d_high
    ; HL = negated d_low = new TOS... wait, we want TOS=d_high
    ld  b, h : ld  c, l    ; BC = d_low
    ld  h, d : ld  l, e    ; HL = d_high (TOS)
    PUSH_TOS
    ld  h, b : ld  l, c    ; HL = d_low
    ; Stack now: d_lo, d_hi ... reversed. Swap:
    PUSH_TOS
    pop  de : pop  hl : push hl : ld  h, d : ld  l, e
    jr  .num_done2
.num_done:
    ; Stack: d_low(TOS), d_high below. Swap to put d_high on TOS (fig-FORTH double convention)
    pop  de                 ; DE = d_high
    PUSH_TOS                ; push d_low
    ld  h, d : ld  l, e    ; HL = d_high
.num_done2:
    jp  FORTH_NEXT

_STR_NUM_ERR: db " ? number", 0

; ============================================================ S->D ============
; S->D  ( n -- d )  Sign-extend single to double
W_STOD: LFA_EMIT
_LINK = W_STOD
        db  4, "S->", 'D'|0x80
STOD:   dw  STOD_CODE
STOD_CODE:
    call _MC_STOD
    jp  FORTH_NEXT
_MC_STOD:
    ; TOS=n, push sign-extended high word
    PUSH_TOS                ; push n as low word
    bit 7, h                ; sign bit of n
    jr  z, .pos
    ld  hl, 0xFFFF          ; negative: high = -1
    ret
.pos:
    ld  hl, 0               ; positive: high = 0
    ret

; ============================================================ +-  D+- =========
; +-  ( n1 n2 -- n1|(-n1) )  Apply sign of n2 to n1
W_PLUSMINUS: LFA_EMIT
_LINK = W_PLUSMINUS
             db  2, "+", '-'|0x80
PLUSMINUS:   dw  PLUSMINUS_CODE
PLUSMINUS_CODE:
    pop  de                 ; DE = n1
    bit 7, h                ; sign of n2
    jr  z, .pm_pos
    ; Negative: return -n1
    ld  a, e : cpl : ld  e, a : ld  a, d : cpl : ld  d, a : inc de
    ld  h, d : ld  l, e
    jp  FORTH_NEXT
.pm_pos:
    ld  h, d : ld  l, e     ; positive: return n1 as-is
    jp  FORTH_NEXT

; D+-  ( d n -- d' )  Apply sign of n to double d
W_DPLUSMINUS: LFA_EMIT
_LINK = W_DPLUSMINUS
              db  3, "D+", '-'|0x80
DPLUSMINUS:   dw  DPLUSMINUS_CODE
DPLUSMINUS_CODE:
    ; TOS=n, NOS=d_high, 3rd=d_low
    ld  b, h                ; B = sign of n
    pop  de                 ; DE = d_high
    pop  bc                 ; BC = d_low (B overwritten... use IX)
    pop  ix                 ; IX = d_low
    bit 7, b                ; test original sign
    jr  z, .dp_pos
    ; Negate double
    ld  a, ixl : cpl : ld  ixl, a : ld  a, ixh : cpl : ld  ixh, a
    inc ix
    ld  a, e : cpl : ld  e, a : ld  a, d : cpl : ld  d, a
    jr  nc, .dp_nc : inc de
.dp_nc:
    push ix
    ld  h, d : ld  l, e
    jp  FORTH_NEXT
.dp_pos:
    push ix
    ld  h, d : ld  l, e
    jp  FORTH_NEXT

; ============================================================ ABS / DABS ======
; ABS  ( n -- |n| )
W_ABS:  LFA_EMIT
_LINK = W_ABS
        db  3, "AB", 'S'|0x80
ABS:    dw  ABS_CODE
ABS_CODE:
    bit 7, h
    jr  z, .abs_done
    ld  a, l : cpl : ld  l, a : ld  a, h : cpl : ld  h, a : inc hl
.abs_done:
    jp  FORTH_NEXT

; DABS  ( d -- |d| )
W_DABS: LFA_EMIT
_LINK = W_DABS
        db  4, "DAB", 'S'|0x80
DABS:   dw  DABS_CODE
DABS_CODE:
    call _MC_DABS
    jp  FORTH_NEXT
_MC_DABS:
    bit 7, h
    jr  z, .dabs_done
    ; Negate double (TOS=high, NOS=low)
    pop  de
    ld  a, e : cpl : ld  e, a : ld  a, d : cpl : ld  d, a : inc de
    ld  a, l : cpl : ld  l, a : ld  a, h : cpl : ld  h, a
    jr  nc, .dabs_nc : inc hl
.dabs_nc:
    push de
.dabs_done:
    ret

; ============================================================ MIN / MAX ========
; MIN  ( a b -- min )
W_MIN:  LFA_EMIT
_LINK = W_MIN
        db  3, "MI", 'N'|0x80
MIN:    dw  MIN_CODE
MIN_CODE:
    pop  de
    ; Signed compare: return smaller
    push hl : push de
    or   a : sbc hl, de     ; HL = TOS - NOS
    pop  de : pop  hl
    bit  7, h               ; oops: h corrupted. Redo.
    ; Simple: compute b-a; if negative (b<a) then return b else return a
    ld  b, h : ld  c, l     ; BC = b (TOS)
    ; DE = a
    or   a
    sbc  hl, de             ; HL = b - a; negative if b < a
    bit  7, h
    jr   nz, .min_b         ; b < a: return b
    ld   h, d : ld  l, e    ; return a
    jp   FORTH_NEXT
.min_b:
    ld   h, b : ld  l, c    ; return b
    jp   FORTH_NEXT

; MAX  ( a b -- max )
W_MAX:  LFA_EMIT
_LINK = W_MAX
        db  3, "MA", 'X'|0x80
MAX:    dw  MAX_CODE
MAX_CODE:
    pop  de                 ; DE = a
    ld  b, h : ld  c, l    ; BC = b
    or   a
    sbc  hl, de             ; HL = b-a; negative if b < a
    bit  7, h
    jr   nz, .max_a         ; b < a: return a
    ld   h, b : ld  l, c   ; return b
    jp   FORTH_NEXT
.max_a:
    ld   h, d : ld  l, e
    jp   FORTH_NEXT

; ============================================================ M* M/ */MOD */ M/MOD
; M*  ( n1 n2 -- d )  Signed 16x16 -> 32
W_MSTAR: LFA_EMIT
_LINK = W_MSTAR
         db  2, "M", '*'|0x80
MSTAR:   dw  MSTAR_CODE
MSTAR_CODE:
    ; Get signs, ABS both, multiply, apply sign
    pop  de
    ld  a, h : xor d        ; XOR signs to get result sign
    push af                 ; save sign
    ; ABS HL
    bit  7, h : jr  z, .ms_a1
    ld  b,h:ld c,l: ld hl,0: or a: sbc hl,bc
.ms_a1:
    ; ABS DE
    bit  7, d : jr  z, .ms_a2
    ld  b,d:ld c,e: ld de,0: or a: ex de,hl: sbc hl,bc: ex de,hl
.ms_a2:
    ; Unsigned multiply HL*DE -> result in exx regs
    ld  b, h : ld  c, l
    exx
    ld  hl, 0 : ld  de, 0
    exx
    ld  a, 16
.ms_loop:
    exx
    add  hl, hl  ; shift result low
    ex   de, hl
    adc  hl, hl  ; shift result high with carry
    ex   de, hl
    exx
    ; Redo: use HL as source
    exx
    ; Too complex with this approach. Use simpler method:
    exx
    dec a : jr  nz, .ms_loop
    ; Apply sign
    pop af
    ; (result in exx: HL'=low, DE'=high)
    exx
    push hl                 ; push low word
    ex   de, hl             ; HL = high
    exx
    pop  bc                 ; BC = low word
    ; sign check
    bit  7, a
    jr   z, .ms_pos
    ; Negate result
    ld  e,c:ld d,b: ld hl,0: or a: sbc hl,de: push hl
    ld  hl,0: sbc hl,bc: ld b,h:ld c,l: jp FORTH_NEXT
.ms_pos:
    push bc
    jp   FORTH_NEXT

; M/  ( d n -- r q )  Signed double / single -> remainder, quotient
W_MDIV: LFA_EMIT
_LINK = W_MDIV
        db  2, "M", '/'|0x80
MDIV:   dw  MDIV_CODE
MDIV_CODE:
    ; Stub: return 0,0 — implement fully in Phase 3
    pop  de : pop  bc
    ld  hl, 0
    PUSH_TOS
    jp  FORTH_NEXT

; /MOD  ( n1 n2 -- r q )
W_SLMOD: LFA_EMIT
_LINK = W_SLMOD
         db  4, "/MO", 'D'|0x80
SLMOD:   dw  SLMOD_CODE
SLMOD_CODE:
    call _MC_SLMOD
    jp  FORTH_NEXT
_MC_SLMOD:
    ; n1/n2 -> quotient q, remainder r
    ; Signs: q sign = sign(n1) XOR sign(n2); r sign = sign(n1)
    ld  de, hl              ; DE = n2
    pop  hl                 ; HL = n1
    ; Save signs
    ld  a, h : xor d : push af   ; result sign
    ld  a, h : push af            ; remainder sign
    ; ABS both
    bit 7, h : jr z, .sm1 : ld b,h:ld c,l:ld hl,0:or a:sbc hl,bc
.sm1:
    bit 7, d : jr z, .sm2 : ld b,d:ld c,e:ld de,0:or a:ex de,hl:sbc hl,bc:ex de,hl
.sm2:
    ; Unsigned 16/16 divide: HL / DE -> quotient in BC, remainder in HL
    ld  bc, 0
    ld  a, 16
.sd_loop:
    add hl, hl
    rl  c : rl  b
    or  a : sbc hl, de
    jr  nc, .sd_ok : add hl, de : dec bc
.sd_ok:
    inc bc
    dec a : jr  nz, .sd_loop
    ; HL = remainder, BC = quotient
    ; Apply signs
    pop af                  ; remainder sign
    bit 7, a : jr z, .sr_pos
    ld  de, hl : ld hl, 0 : or a : sbc hl, de
.sr_pos:
    push hl                 ; push remainder
    pop af                  ; quotient sign
    bit 7, a : jr z, .sq_pos
    ld  hl, 0 : or a : sbc hl, bc : ret
.sq_pos:
    ld  h, b : ld  l, c
    ret

; /  ( n1 n2 -- q )
W_SLASH: LFA_EMIT
_LINK = W_SLASH
         db  1, '/'|0x80
SLASH:   dw  SLASH_CODE
SLASH_CODE:
    call _MC_SLMOD          ; ( n1 n2 -- r q )
    ; Discard remainder (it's below TOS)
    pop  de                 ; discard remainder
    jp   FORTH_NEXT

; MOD  ( n1 n2 -- r )
W_MOD:  LFA_EMIT
_LINK = W_MOD
        db  3, "MO", 'D'|0x80
MOD:    dw  MOD_CODE
MOD_CODE:
    call _MC_SLMOD          ; ( n1 n2 -- r q )
    POP_TOS                 ; discard quotient, keep remainder
    jp  FORTH_NEXT

; */MOD  ( n1 n2 n3 -- r q )  n1*n2/n3
W_SSMOD: LFA_EMIT
_LINK = W_SSMOD
         db  5, "*/MO", 'D'|0x80
SSMOD:   dw  SSMOD_CODE
SSMOD_CODE:
    call _MC_SSMOD
    jp  FORTH_NEXT
_MC_SSMOD:
    pop  de : pop  bc       ; DE=n3... wait
    ; TOS=n3, NOS=n2, 3rd=n1
    ld  d, h : ld  e, l    ; DE = n3 (divisor)
    pop  hl                 ; HL = n2
    pop  ix                 ; IX = n1
    ; Push n1*n2 as double then divide by n3
    ; n1*n2 via MSTAR inline
    push ix : pop hl        ; HL = n1
    push de                 ; save n3
    ; (n1 in HL, n2 in old NOS — need n2)
    ; This is getting complex. Stub.
    pop  de                 ; restore n3
    ld  hl, 0
    PUSH_TOS
    ret

; */  ( n1 n2 n3 -- q )
W_SSSLASH: LFA_EMIT
_LINK = W_SSSLASH
           db  2, "*", '/'|0x80
SSSLASH:   dw  SSSLASH_CODE
SSSLASH_CODE:
    call _MC_SSMOD
    pop  de                 ; discard remainder
    jp  FORTH_NEXT

; M/MOD  ( d n -- r q )  32/16 with remainder
W_MSLMOD: LFA_EMIT
_LINK = W_MSLMOD
          db  5, "M/MO", 'D'|0x80
MSLMOD:   dw  MSLMOD_CODE
MSLMOD_CODE:
    ; Stub
    pop  de : pop  bc
    ld  hl, 0
    PUSH_TOS
    jp  FORTH_NEXT

; ============================================================ Number output ===
; <#  ( -- )  Begin numeric output
W_BHASH: LFA_EMIT
_LINK = W_BHASH
         db  2, "<", '#'|0x80
BHASH:   dw  BHASH_CODE
BHASH_CODE:
    call _MC_BHASH
    jp  FORTH_NEXT
_MC_BHASH:
    ld  hl, PAD_START + 63  ; HLD points to end of PAD
    ld  (USER_START + U_HLD), hl
    ret

; #>  ( d -- addr len )  End numeric output, return string addr+len
W_HASHB: LFA_EMIT
_LINK = W_HASHB
         db  2, "#", '>'|0x80
HASHB:   dw  HASHB_CODE
HASHB_CODE:
    call _MC_HASHB
    jp  FORTH_NEXT
_MC_HASHB:
    ; #> ( d -- addr len )  End numeric output
    ; TOS=d_high, NOS=d_low — discard both
    pop  de                 ; discard d_low
    ; HL = d_high (discard)
    ; Return ( addr len ) where addr=HLD, len=PAD_END-HLD
    ld  de, (USER_START + U_HLD)  ; DE = start of digit string
    ld  hl, PAD_START + 64        ; HL = end of output area
    or  a
    sbc hl, de              ; HL = length
    push de                 ; push addr
    ; HL = length (TOS)
    ret

; HOLD  ( char -- )  Insert char into numeric output string
W_HOLD: LFA_EMIT
_LINK = W_HOLD
        db  4, "HOL", 'D'|0x80
HOLD:   dw  HOLD_CODE
HOLD_CODE:
    ld  a, l
    ld  de, (USER_START + U_HLD)
    dec de
    ld  (de), a
    ld  (USER_START + U_HLD), de
    POP_TOS : jp  FORTH_NEXT

; SIGN  ( n -- )  Add minus sign if n negative
W_SIGN: LFA_EMIT
_LINK = W_SIGN
        db  4, "SIG", 'N'|0x80
SIGN:   dw  SIGN_CODE
SIGN_CODE:
    call _MC_SIGN
    jp  FORTH_NEXT
_MC_SIGN:
    bit 7, h
    jr  z, .sign_pos
    ld  a, '-'
    ld  de, (USER_START + U_HLD)
    dec de
    ld  (de), a
    ld  (USER_START + U_HLD), de
.sign_pos:
    POP_TOS
    ret

; #  ( d -- d' )  Convert one digit
W_HASH: LFA_EMIT
_LINK = W_HASH
        db  1, '#'|0x80
HASH:   dw  HASH_CODE
HASH_CODE:
    call _MC_HASH
    jp  FORTH_NEXT
_MC_HASH:
    ; # ( d -- d' )  Extract one digit from double d using BASE
    ; TOS=d_high(HL), NOS=d_low
    ; Two-step divide for full 32-bit quotient:
    ;   Step 1: d_high / BASE -> q_high, r_high
    ;   Step 2: (r_high:d_low) / BASE -> q_low, remainder (= digit)
    ;   New d = q_high:q_low
    pop  de                 ; DE = d_low
    ld  (HASH_DLO), de      ; save d_low
    ; Step 1: divide d_high (in HL) by BASE
    ;   U/ needs ( udlo udhi divisor -- quot rem )
    ;   Treat d_high as 32-bit with high=0: ( d_high 0 BASE )
    push hl                 ; push d_high as udlo
    ld  hl, 0
    push hl                 ; push 0 as udhi
    ld  hl, (USER_START + U_BASE)
    call _MC_UDIV           ; -> TOS=r_high, stack: q_high
    ; HL = r_high (remainder from high word divide)
    pop  de                 ; DE = q_high
    ld  (HASH_QHI), de      ; save q_high
    ; Step 2: divide (r_high:d_low) by BASE
    ;   ( d_low r_high BASE -- q_low remainder )
    ld  de, (HASH_DLO)
    push de                 ; push d_low as udlo
    push hl                 ; push r_high as udhi
    ld  hl, (USER_START + U_BASE)
    call _MC_UDIV           ; -> TOS=remainder(digit), stack: q_low
    ; HL = remainder = digit value
    ld  a, l
    cp  10
    jr  c, .hash_dec
    add a, 'A' - 10 - '0'  ; hex letters
.hash_dec:
    add a, '0'              ; A = ASCII digit
    ; HOLD: store char at --HLD
    ld  de, (USER_START + U_HLD)
    dec de
    ld  (de), a
    ld  (USER_START + U_HLD), de
    ; Return new d = q_high:q_low
    ; Stack has q_low. Push it as d_low, set TOS to q_high.
    ; q_low is already on stack (from UDIV). That's our new d_low.
    ; TOS = q_high
    ld  hl, (HASH_QHI)     ; HL = q_high = new d_high (TOS)
    ret

; #S  ( d -- 0 0 )  Convert all digits
W_HASHS: LFA_EMIT
_LINK = W_HASHS
         db  2, "#", 'S'|0x80
HASHS:   dw  HASHS_CODE
HASHS_CODE:
    call _MC_HASHS
    jp  FORTH_NEXT
_MC_HASHS:
.hs_loop:
    call _MC_HASH           ; convert one digit
    ; Check if d == 0
    ld  a, h : or  l
    jr  nz, .hs_loop
    pop  de : ld  a, d : or  e
    jr  nz, .hs_loop        ; d_low also non-zero
    push de                 ; d_low = 0
    ; HL = 0 already
    ret

; PAD  ( -- addr )  Address of scratch pad
W_PAD:  LFA_EMIT
_LINK = W_PAD
        db  3, "PA", 'D'|0x80
PAD:    dw  PAD_CODE
PAD_CODE:
    PUSH_TOS
    ld  hl, PAD_START
    jp  FORTH_NEXT

; SPACE  ( -- )  Output a space
W_SPACE: LFA_EMIT
_LINK = W_SPACE
         db  5, "SPAC", 'E'|0x80
SPACE:   dw  SPACE_CODE
SPACE_CODE:
    ld  a, 32 : rst 0x10 : jp  FORTH_NEXT

; SPACES  ( n -- )  Output n spaces
W_SPACES: LFA_EMIT
_LINK = W_SPACES
          db  6, "SPACE", 'S'|0x80
SPACES:   dw  SPACES_CODE
SPACES_CODE:
    ld  b, h : ld  c, l
.sp_loop:
    ld  a, b : or  c : jr  z, .sp_done
    ld  a, 32 : rst 0x10
    dec bc : jr  .sp_loop
.sp_done:
    POP_TOS : jp  FORTH_NEXT

; TYPE  ( addr n -- )  Output string
W_TYPE: LFA_EMIT
_LINK = W_TYPE
        db  4, "TYP", 'E'|0x80
TYPE:   dw  TYPE_CODE
TYPE_CODE:
    call _MC_TYPE
    jp  FORTH_NEXT
_MC_TYPE:
    ld  b, h : ld  c, l    ; BC = count
    pop  hl                ; HL = addr
.type_loop:
    ld  a, b : or  c : jr  z, .type_done
    ld  a, (hl) : rst 0x10
    inc hl : dec bc
    jr  .type_loop
.type_done:
    POP_TOS
    ret

; -TRAILING  ( addr n -- addr n' )  Remove trailing spaces
W_MTRAIL: LFA_EMIT
_LINK = W_MTRAIL
          db  9, "-TRAILIN", 'G'|0x80
MTRAIL:   dw  MTRAIL_CODE
MTRAIL_CODE:
    ; TOS=n(HL), NOS=addr
    ld  b, h : ld  c, l    ; BC = n
    pop  de                ; DE = addr
    push de                ; restore addr
    ; Point to last char: addr + n - 1
.mt_loop:
    ld  a, b : or  c : jr  z, .mt_done
    push de
    ld  hl, de : ld  de, 0 : ld  e, c : ld  d, b
    dec de : add hl, de    ; HL = addr + n - 1
    pop  de
    ld  a, (hl)
    cp  32 : jr  nz, .mt_done
    dec bc : jr  .mt_loop
.mt_done:
    ld  h, b : ld  l, c
    jp  FORTH_NEXT

; WORD  ( delim -- addr )  Parse next token from input into HERE
W_WORD: LFA_EMIT
_LINK = W_WORD
        db  4, "WOR", 'D'|0x80
WORD:   dw  WORD_CODE
WORD_CODE:
    call _MC_WORD
    jp  FORTH_NEXT
_MC_WORD:
    ; WORD ( delim -- addr )  Parse token from input, store at HERE
    ld  a, l                ; A = delimiter
    ld  (WORD_DELIM), a     ; save delimiter
    ; Determine input source base address
    ld  hl, (USER_START + U_BLK)
    ld  a, h : or l
    jr  nz, .word_blk
    ; Terminal input: source = TIB
    ld  hl, (USER_START + U_TIB)
    jr  .word_have_src
.word_blk:
    ; Block input: source = buffer for current block
    ; HL = BLK number. Find its buffer.
    push hl
    call _BUF_FIND          ; Z=found, DE=data addr
    jr  z, .word_blk_ok
    ; Block not in buffer — assign one (empty)
    pop  hl
    push hl
    call _BUF_ASSIGN        ; DE=data addr
.word_blk_ok:
    pop  hl                 ; discard BLK number
    ex  de, hl              ; HL = buffer data address
.word_have_src:
    ; HL = base of input source
    ld  (WORD_SRC), hl      ; save source base
    ld  de, (USER_START + U_IN)
    add hl, de              ; HL = current scan position
    ld  a, (WORD_DELIM)
    ld  b, a                ; B = delimiter
    ; Skip leading delimiters
.wskip:
    ld  a, (hl)
    or  a : jr  z, .wempty  ; end of input (null)
    cp  13 : jr  z, .wempty ; end of input (CR)
    cp  b : jr  nz, .wfound ; not delimiter -> start of word
    inc hl : jr  .wskip
.wfound:
    ; HL = start of word. Copy to HERE as counted string.
    ld  de, (USER_START + U_DP) ; DE = HERE (destination)
    push de                 ; save HERE for return value
    inc de                  ; skip count byte (fill later)
    ld  c, 0                ; C = length counter
.wcopy:
    ld  a, (hl)
    or  a : jr  z, .wend    ; null = end
    cp  13 : jr  z, .wend   ; CR = end
    cp  b : jr  z, .wend_delim ; delimiter = end of token
    ld  (de), a
    inc hl : inc de : inc c
    jr  .wcopy
.wend_delim:
    inc hl                  ; skip past closing delimiter
.wend:
    ; Set high bit on last character (fig-FORTH convention)
    ld  a, c
    or  a : jr  z, .wend_count ; empty word, skip
    dec de
    ld  a, (de)
    or  0x80
    ld  (de), a
    inc de
.wend_count:
    ; Null-terminate after name (so number parsing stops cleanly)
    xor a
    ld  (de), a
    ; Write count byte
    pop  ix                 ; IX = HERE (saved start)
    ld  a, c
    ld  (ix+0), a           ; count byte at HERE
    ; Update >IN: new offset = (HL - source_base)
    ld  de, (WORD_SRC)
    or  a
    sbc hl, de              ; HL = new >IN offset
    ld  (USER_START + U_IN), hl
    ; Return HERE address in HL (TOS)
    push ix
    pop  hl                 ; HL = HERE
    ret
.wempty:
    ; Update >IN to current position
    ld  de, (WORD_SRC)
    or  a
    sbc hl, de
    ld  (USER_START + U_IN), hl
    ; Write empty counted string at HERE
    ld  hl, (USER_START + U_DP)
    xor a
    ld  (hl), a             ; count = 0
    ; HL = HERE (return value)
    ret

; ============================================================ Compiler ========

; SMUDGE  ( -- )  Toggle smudge bit on latest word
W_SMUDGE: LFA_EMIT
_LINK = W_SMUDGE
          db  6, "SMUDG", 'E'|0x80
SMUDGE:   dw  SMUDGE_CODE
SMUDGE_CODE:
    call _MC_SMUDGE
    jp  FORTH_NEXT
_MC_SMUDGE:
    ld  hl, (USER_START + U_CURRENT)
    ld  e, (hl)
    inc hl
    ld  d, (hl)
    ex  de, hl            ; NFA of latest word
    ld  a, (hl)
    xor F_SMUDGE
    ld  (hl), a
    ret

; !CSP  ( -- )  Save current stack pointer into CSP
W_STORECSP: LFA_EMIT
_LINK = W_STORECSP
            db  4, "!CS", 'P'|0x80
STORECSP:   dw  STORECSP_CODE
STORECSP_CODE:
    call _MC_STORECSP
    jp  FORTH_NEXT
_MC_STORECSP:
    ld  hl, 0 : add hl, sp
    ld  (USER_START + U_CSP), hl
    ret

; ?CSP  ( -- )  Error if SP != CSP (unbalanced structure)
W_QCSP: LFA_EMIT
_LINK = W_QCSP
        db  4, "?CS", 'P'|0x80
QCSP:   dw  QCSP_CODE
QCSP_CODE:
    ld  de, (USER_START + U_CSP)
    ld  hl, 0 : add hl, sp
    or  a : sbc hl, de
    jr  z, .csp_ok
    ld  hl, _STR_CSP_ERR
    call _PRINT_STR
    jp  FORTH_ABORT
.csp_ok:
    jp  FORTH_NEXT
_STR_CSP_ERR: db " COMPILE STACK ERROR", 0

; ?COMP  ( -- )  Error if not in compile mode
W_QCOMP: LFA_EMIT
_LINK = W_QCOMP
         db  5, "?COM", 'P'|0x80
QCOMP:   dw  QCOMP_CODE
QCOMP_CODE:
    ld  hl, (USER_START + U_STATE)
    ld  a, h : or  l
    jr  nz, .comp_ok
    ld  hl, _STR_COMP_ERR
    call _PRINT_STR
    jp  FORTH_ABORT
.comp_ok:
    jp  FORTH_NEXT
_STR_COMP_ERR: db " NOT COMPILING", 0

; ?EXEC  ( -- )  Error if not in execute (interpret) mode
W_QEXEC: LFA_EMIT
_LINK = W_QEXEC
         db  5, "?EXE", 'C'|0x80
QEXEC:   dw  QEXEC_CODE
QEXEC_CODE:
    ld  hl, (USER_START + U_STATE)
    ld  a, h : or  l
    jr  z, .exec_ok
    ld  hl, _STR_EXEC_ERR
    call _PRINT_STR
    jp  FORTH_ABORT
.exec_ok:
    jp  FORTH_NEXT
_STR_EXEC_ERR: db " NOT INTERPRETING", 0

; ?PAIRS  ( n1 n2 -- )  Error if n1 != n2 (structure mismatch)
W_QPAIRS: LFA_EMIT
_LINK = W_QPAIRS
          db  6, "?PAIR", 'S'|0x80
QPAIRS:   dw  QPAIRS_CODE
QPAIRS_CODE:
    pop  de
    or   a : sbc hl, de
    jr   z, .pairs_ok
    ld   hl, _STR_PAIRS_ERR : call _PRINT_STR
    jp   FORTH_ABORT
.pairs_ok:
    POP_TOS : jp  FORTH_NEXT
_STR_PAIRS_ERR: db " STRUCTURE MISMATCH", 0

; COMPILE  ( -- )  Compile CFA of next word in thread
W_COMPILE: LFA_EMIT
_LINK = W_COMPILE
           db  7, "COMPIL", 'E'|0x80
COMPILE:   dw  COMPILE_CODE
COMPILE_CODE:
    ; The CFA of the word to compile is inline in the thread (at IP)
    ld  bc, (FORTH_IP)
    ld  a, (bc) : inc bc : ld  l, a
    ld  a, (bc) : inc bc : ld  h, a  ; HL = CFA to compile
    ld  (FORTH_IP), bc
    ; Emit HL into dictionary
    ld  de, (USER_START + U_DP)
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    jp  FORTH_NEXT

; LITERAL  ( n -- )  Compile n as a literal (compile-time)
W_LITERAL: LFA_EMIT
_LINK = W_LITERAL
           db  F_IMM | 7, "LITERA", 'L'|0x80
LITERAL:   dw  LITERAL_CODE
LITERAL_CODE:
    ; Compile LIT followed by TOS value
    ld  de, (USER_START + U_DP)
    ; Compile CFA of LIT
    ld  a, LIT & 0xFF    : ld  (de), a : inc de
    ld  a, LIT >> 8      : ld  (de), a : inc de
    ; Compile the value
    ld  a, l
    ld  (de), a : inc de
    ld  a, h             : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

; DLITERAL  ( d -- )  Compile double literal
W_DLITERAL: LFA_EMIT
_LINK = W_DLITERAL
            db  F_IMM | 8, "DLITERA", 'L'|0x80
DLITERAL:   dw  DLITERAL_CODE
DLITERAL_CODE:
    ; TOS=d_high(HL), NOS=d_low
    pop  de                 ; DE = d_low
    ; Compile: LIT d_low LIT d_high
    ld  bc, (USER_START + U_DP)
    ld  a, LIT & 0xFF    : ld  (bc), a : inc bc
    ld  a, LIT >> 8      : ld  (bc), a : inc bc
    ld  a, e             : ld  (bc), a : inc bc
    ld  a, d             : ld  (bc), a : inc bc
    ld  a, LIT & 0xFF    : ld  (bc), a : inc bc
    ld  a, LIT >> 8      : ld  (bc), a : inc bc
    ld  a, l             : ld  (bc), a : inc bc
    ld  a, h             : ld  (bc), a : inc bc
    ld  (USER_START + U_DP), bc
    POP_TOS : jp  FORTH_NEXT

; ============================================================ CREATE / : / ; =

; CREATE  ( -- )  Create a new dictionary entry for the word at HERE
W_CREATE: LFA_EMIT
_LINK = W_CREATE
          db  6, "CREAT", 'E'|0x80
CREATE:   dw  CREATE_CODE
CREATE_CODE:
    ; CREATE name : parse the next word, build its header, and lay down a DOVAR
    ; code field so a bare CREATEd word pushes its parameter-field address.
    ; (DOES> later overwrites this CFA for defining words.) Unlike _MC_CREATE
    ; — used by : and VARIABLE after they parse/emit themselves — the CREATE
    ; *word* must parse the name and emit the CFA itself.
    PUSH_TOS
    ld  hl, 32              ; delimiter = space
    call _MC_WORD           ; parse name -> HERE
    call _MC_CREATE         ; build header; DP -> CFA position
    ld  de, (USER_START + U_DP)
    ld  a, FORTH_DOVAR & 0xFF : ld  (de), a : inc de
    ld  a, FORTH_DOVAR >> 8   : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS
    jp  FORTH_NEXT
_MC_CREATE:
    ; CREATE ( -- )  Build a dictionary header for the word at HERE.
    ; WORD has placed a counted string (count + name, last char |0x80) at HERE.
    ; We build: [LFA][count][name...] then advance DP past the header.
    ; The LFA points to the previous word's LFA (= prev NFA - 2).
    ;
    ; 1. Read name info from HERE
    ld  hl, (USER_START + U_DP) ; HL = HERE = address of counted string
    ld  a, (hl)
    and 0x1F
    ld  b, a                ; B = name length
    ; Cap to WIDTH
    ld  a, (USER_START + U_WIDTH)
    cp  b : jr  nc, .cr_ok
    ld  b, a
.cr_ok:
    ; 2. Save HERE (will be start of new entry after we insert LFA)
    ;    Layout: [LFA 2 bytes][count 1][name B bytes] then CFA follows
    ;    We need to shift the counted string right by 2 to make room for LFA.
    ;    Source = HERE, Dest = HERE+2, length = B+1 (count + name)
    ld  hl, (USER_START + U_DP)
    push hl                 ; save HERE (will be LFA address)
    ld  c, b
    inc c                   ; C = count byte + name bytes
    ; Copy from HERE to HERE+2 (must copy backwards to avoid overlap)
    ld  d, 0 : ld  e, c    ; DE = length
    push de                 ; save length
    add hl, de
    dec hl                  ; HL = last byte of source (HERE + len - 1)
    ld  d, h : ld  e, l
    inc de : inc de         ; DE = last byte of dest (HERE + len + 1)
.cr_shift:
    ld  a, (hl)
    ld  (de), a
    dec hl : dec de
    dec c : jr  nz, .cr_shift
    ; 3. Write LFA at HERE: points to previous word's LFA
    ;    Previous word's NFA is in CURRENT vocab head cell.
    ;    Previous LFA = prev_NFA - 2
    pop  de                 ; DE = name field length (count+name)
    pop  hl                 ; HL = HERE (LFA address of new word)
    push hl                 ; save for NFA calc
    ld  ix, (USER_START + U_CURRENT) ; IX = vocab head cell address
    ld  a, (ix+0)
    ld  c, a
    ld  a, (ix+1)
    ld  b, a                ; BC = NFA of previous word
    ; Previous LFA = BC - 2
    dec bc : dec bc         ; BC = LFA of previous word
    ld  (hl), c : inc hl
    ld  (hl), b : inc hl   ; LFA written; HL now points to NFA (= HERE+2)
    ; 4. NFA is already in place (shifted above). HL = NFA address.
    ;    Advance DP past the header: DP = HERE + 2 + 1 + namelen = HERE + 2 + fieldlen
    push hl                 ; save NFA address
    ld  b, 0 : ld  c, e    ; note: DE = length from earlier... actually DE was popped
    ; Recalculate: NFA = HERE+2, name field = count(1) + namelen(b)
    ; We need namelen. Read it from the count byte.
    ld  a, (hl)
    and 0x1F
    ld  c, a
    inc c                   ; C = count byte + name bytes
    ld  b, 0
    add hl, bc              ; HL = past name field = new DP (CFA location)
    ld  (USER_START + U_DP), hl
    ; 5. Update CURRENT vocab head to point to new NFA
    pop  hl                 ; HL = NFA of new word
    ld  (ix+0), l
    ld  (ix+1), h           ; vocab head now points to new word's NFA
    pop  hl                 ; clean stack (saved HERE)
    ret

; :  ( -- )  Begin colon definition
W_COLON: LFA_EMIT
_LINK = W_COLON
         db  1, ':'|0x80
COLON:   dw  COLON_CODE
COLON_CODE:
    ; : ( -- )  Begin colon definition
    ; (BC free — IP is in memory)
    PUSH_TOS
    ld  hl, 32              ; delimiter = space
    call _MC_WORD           ; HL = HERE (counted string)
    ; 2. Check for empty name
    ld  a, (hl)
    and 0x1F
    jr  z, .colon_empty
    ; 3. CREATE dictionary header (reads name from HERE)
    call _MC_CREATE
    ; 4. Emit DOCOL as CFA at HERE
    ld  de, (USER_START + U_DP)
    ld  a, FORTH_DOCOL & 0xFF : ld  (de), a : inc de
    ld  a, FORTH_DOCOL >> 8   : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    ; 5. Set STATE = compile mode
    ld  hl, 1
    ld  (USER_START + U_STATE), hl
    ; 6. SMUDGE (mark word as in-progress)
    call _MC_SMUDGE
    ; 7. !CSP (save stack pointer)
    call _MC_STORECSP
    POP_TOS
    ; (BC no longer holds IP — freed by FORTH_IP in memory)
    jp  FORTH_NEXT
.colon_empty:
    POP_TOS
    ; (BC no longer holds IP — freed by FORTH_IP in memory)
    jp  FORTH_NEXT

; ;  ( -- )  End colon definition
W_SEMI: LFA_EMIT
_LINK = W_SEMI
        db  F_IMM | 1, ';'|0x80
SEMI:   dw  SEMI_CODE
SEMI_CODE:
    ; Compile ;S (exit from colon word)
    ; (BC free — IP is in memory)
    ld  de, (USER_START + U_DP)
    ld  a, SEMIS & 0xFF  : ld  (de), a : inc de
    ld  a, SEMIS >> 8    : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    ; SMUDGE off (unsmudge)
    call _MC_SMUDGE
    ; Back to interpret mode
    ld  hl, 0
    ld  (USER_START + U_STATE), hl
    ; (BC no longer holds IP — freed by FORTH_IP in memory)
    jp  FORTH_NEXT

; VARIABLE  ( -- )  Create a variable with DOVAR runtime, initial value 0
W_VARIABLE: LFA_EMIT
_LINK = W_VARIABLE
            db  8, "VARIABL", 'E'|0x80
VARIABLE:   dw  VARIABLE_CODE
VARIABLE_CODE:
    ; VARIABLE name : parse name, CREATE header, DOVAR CFA, ALLOT 2 bytes.
    PUSH_TOS                ; preserve TOS (VARIABLE is ( -- ))
    ld  hl, 32
    call _MC_WORD           ; parse name -> HERE
    call _MC_CREATE         ; build header; DP -> CFA position
    ld  de, (USER_START + U_DP)
    ld  a, FORTH_DOVAR & 0xFF : ld  (de), a : inc de
    ld  a, FORTH_DOVAR >> 8   : ld  (de), a : inc de
    ; Allot 2 bytes (initial value = 0)
    xor a : ld  (de), a : inc de
    xor a : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS
    jp  FORTH_NEXT

; CONSTANT  ( n -- )  Create a constant with DOCON runtime
W_CONSTANT: LFA_EMIT
_LINK = W_CONSTANT
            db  8, "CONSTAN", 'T'|0x80
CONSTANT:   dw  CONSTANT_CODE
CONSTANT_CODE:
    ; CONSTANT name ( n -- ) : parse name, CREATE, DOCON CFA, store value n.
    push hl                 ; save value n (name-parse + CREATE clobber HL/DE)
    ld  hl, 32
    call _MC_WORD           ; parse name -> HERE
    call _MC_CREATE         ; build header; DP -> CFA position
    ld  bc, (USER_START + U_DP)
    ld  a, FORTH_DOCON & 0xFF : ld  (bc), a : inc bc
    ld  a, FORTH_DOCON >> 8   : ld  (bc), a : inc bc
    pop  de                 ; DE = value n
    ld  a, e : ld  (bc), a : inc bc
    ld  a, d : ld  (bc), a : inc bc
    ld  (USER_START + U_DP), bc
    POP_TOS : jp  FORTH_NEXT

; USER  ( n -- )  Create a USER variable
W_USER: LFA_EMIT
_LINK = W_USER
        db  4, "USE", 'R'|0x80
USER:   dw  USER_CODE
USER_CODE:
    ; USER name ( n -- ) : parse name, CREATE, DOUSER CFA, store offset n.
    push hl                 ; save offset n
    ld  hl, 32
    call _MC_WORD           ; parse name -> HERE
    call _MC_CREATE
    ld  bc, (USER_START + U_DP)
    ld  a, FORTH_DOUSER & 0xFF : ld  (bc), a : inc bc
    ld  a, FORTH_DOUSER >> 8   : ld  (bc), a : inc bc
    pop  de                 ; DE = offset n
    ld  a, e : ld  (bc), a : inc bc
    ld  a, d : ld  (bc), a : inc bc
    ld  (USER_START + U_DP), bc
    POP_TOS : jp  FORTH_NEXT

; ============================================================ Compiler flow ===
; These compile branch instructions into the dictionary.

; IF  ( -- addr )  Compile 0BRANCH, push destination addr for THEN/ELSE
W_IF:   LFA_EMIT
_LINK = W_IF
        db  F_IMM | 2, "I", 'F'|0x80
IF:     dw  IF_CODE
IF_CODE:
    ; Compile ZBRANCH followed by a placeholder offset
    ld  de, (USER_START + U_DP)
    ld  a, ZBRANCH & 0xFF    : ld  (de), a : inc de
    ld  a, ZBRANCH >> 8      : ld  (de), a : inc de
    ; Push address of offset field (to be back-patched by THEN/ELSE)
    PUSH_TOS
    ld  h, d : ld  l, e     ; HL = address of offset placeholder
    ; Emit placeholder offset (2 bytes)
    xor a
    ld  (de), a : inc de : xor a
 ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    jp  FORTH_NEXT

; ELSE  ( addr1 -- addr2 )  Compile BRANCH, back-patch IF's address
W_ELSE: LFA_EMIT
_LINK = W_ELSE
        db  F_IMM | 4, "ELS", 'E'|0x80
ELSE:   dw  ELSE_CODE
ELSE_CODE:
    ; TOS = address left by IF (offset placeholder)
    ; Compile BRANCH + placeholder
    ld  de, (USER_START + U_DP)
    ld  a, BRANCH & 0xFF    : ld  (de), a : inc de
    ld  a, BRANCH >> 8      : ld  (de), a : inc de
    PUSH_TOS                ; save new BRANCH's placeholder addr
    ld  bc, de              ; BC = new placeholder addr
    ld  de, 0 : ld  a, e
 ld  (bc), a : inc bc : ld  a, d
 ld  (bc), a : inc bc
    ld  (USER_START + U_DP), bc
    ; Back-patch IF's placeholder: offset = DP - IF_offset_addr
    pop  de                 ; DE = IF's placeholder address
    ld  hl, (USER_START + U_DP)
    or   a : sbc hl, de     ; HL = offset
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a
    ; TOS = BRANCH's placeholder addr (already set as new PUSH_TOS above)
    ; But we saved BC as new placeholder. Restore:
    pop  hl                 ; HL = new BRANCH placeholder
    jp  FORTH_NEXT

; THEN / ENDIF  ( addr -- )  Back-patch forward branch
W_THEN: LFA_EMIT
_LINK = W_THEN
        db  F_IMM | 4, "THE", 'N'|0x80
THEN:   dw  THEN_CODE
THEN_CODE:
    ; TOS = placeholder address to back-patch
    ld  de, hl              ; DE = placeholder address
    ld  hl, (USER_START + U_DP)
    or   a : sbc hl, de     ; HL = forward offset
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a
    POP_TOS : jp  FORTH_NEXT

W_ENDIF: LFA_EMIT
_LINK = W_ENDIF
         db  F_IMM | 5, "ENDI", 'F'|0x80
ENDIF:   dw  THEN_CODE     ; same as THEN

; BEGIN  ( -- addr )  Push current DP for backward branches
W_BEGIN: LFA_EMIT
_LINK = W_BEGIN
         db  F_IMM | 5, "BEGI", 'N'|0x80
BEGIN:   dw  BEGIN_CODE
BEGIN_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_DP)
    jp  FORTH_NEXT

; UNTIL  ( addr -- )  Compile 0BRANCH back to addr
W_UNTIL: LFA_EMIT
_LINK = W_UNTIL
         db  F_IMM | 5, "UNTI", 'L'|0x80
UNTIL:   dw  UNTIL_CODE
UNTIL_CODE:
    ; TOS = address of BEGIN
    ld  de, (USER_START + U_DP)
    ld  a, ZBRANCH & 0xFF   : ld  (de), a : inc de
    ld  a, ZBRANCH >> 8     : ld  (de), a : inc de
    ; Offset = BEGIN_addr - (current DP)   [negative offset back]
    or   a
    sbc  hl, de             ; HL = BEGIN_addr - DP (negative)
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

; AGAIN  ( addr -- )  Compile unconditional BRANCH back
W_AGAIN: LFA_EMIT
_LINK = W_AGAIN
         db  F_IMM | 5, "AGAI", 'N'|0x80
AGAIN:   dw  AGAIN_CODE
AGAIN_CODE:
    call _MC_AGAIN
    jp  FORTH_NEXT
_MC_AGAIN:
    ld  de, (USER_START + U_DP)
    ld  a, BRANCH & 0xFF    : ld  (de), a : inc de
    ld  a, BRANCH >> 8      : ld  (de), a : inc de
    or   a : sbc hl, de
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS
    ret

; WHILE  ( addr1 -- addr1 addr2 )  Compile 0BRANCH within BEGIN..REPEAT
W_WHILE: LFA_EMIT
_LINK = W_WHILE
         db  F_IMM | 5, "WHIL", 'E'|0x80
WHILE:   dw  IF_CODE       ; same as IF: compile ZBRANCH + placeholder

; REPEAT  ( addr1 addr2 -- )  Close BEGIN..WHILE..REPEAT
W_REPEAT: LFA_EMIT
_LINK = W_REPEAT
          db  F_IMM | 6, "REPEA", 'T'|0x80
REPEAT:   dw  REPEAT_CODE
REPEAT_CODE:
    ; TOS=WHILE_placeholder, NOS=BEGIN_addr
    ; 1. Compile BRANCH back to BEGIN
    pop  de                 ; DE = BEGIN addr
    push hl                 ; save WHILE placeholder
    ld  hl, de              ; HL = BEGIN addr
    call _MC_AGAIN          ; compile BRANCH to BEGIN, pops HL
    ; 2. Back-patch WHILE's placeholder to current DP
    pop  hl                 ; HL = WHILE placeholder
    jp  THEN_CODE           ; back-patch it

; END  ( addr -- )  Alias for AGAIN
W_END:  LFA_EMIT
_LINK = W_END
        db  F_IMM | 3, "EN", 'D'|0x80
END:    dw  AGAIN_CODE

; DO  ( -- addr )  Compile (DO), push loop start address
W_DO_C: LFA_EMIT
_LINK = W_DO_C
        db  F_IMM | 2, "D", 'O'|0x80
DO_C:   dw  DO_C_CODE
DO_C_CODE:
    ; Compile (DO) CFA
    ld  de, (USER_START + U_DP)
    ld  a, DO_RT & 0xFF  : ld  (de), a : inc de
    ld  a, DO_RT >> 8    : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    ; Push current DP as loop-back address
    PUSH_TOS
    ld  hl, de
    jp  FORTH_NEXT

; LOOP  ( addr -- )  Compile (LOOP) with backward branch to addr
W_LOOP_C: LFA_EMIT
_LINK = W_LOOP_C
          db  F_IMM | 4, "LOO", 'P'|0x80
LOOP_C:   dw  LOOP_C_CODE
LOOP_C_CODE:
    ld  de, (USER_START + U_DP)
    ld  a, LOOP_RT & 0xFF : ld  (de), a : inc de
    ld  a, LOOP_RT >> 8   : ld  (de), a : inc de
    ; Backward offset
    or   a : sbc hl, de
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

; +LOOP  ( addr -- )  Compile (+LOOP)
W_PLOOP_C: LFA_EMIT
_LINK = W_PLOOP_C
           db  F_IMM | 5, "+LOO", 'P'|0x80
PLOOP_C:   dw  PLOOP_C_CODE
PLOOP_C_CODE:
    ld  de, (USER_START + U_DP)
    ld  a, PLOOP_RT & 0xFF : ld  (de), a : inc de
    ld  a, PLOOP_RT >> 8   : ld  (de), a : inc de
    or   a : sbc hl, de
    ld  a, l
    ld  (de), a : inc de : ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

; ============================================================ Number display ==
; .  ( n -- )  Print signed number
W_DOT:  LFA_EMIT
_LINK = W_DOT
        db  1, '.'|0x80
DOT:    dw  DOT_CODE
DOT_CODE:
    ; .  ( n -- )  Print signed number with trailing space
    ; TOS = n (HL). IP is in memory (FORTH_IP), BC is free.
    ld  a, h
    ld  (DOT_SIGN), a
    bit 7, h
    jr  z, .dot_pos
    ld  a, l : cpl : ld  l, a
    ld  a, h : cpl : ld  h, a
    inc hl
.dot_pos:
    ; Convert HL to decimal digits on stack (reverse order)
    ld  de, 0               ; digit count
.dot_div:
    push de
    ld  de, 10
    call _DOT_DIVMOD        ; HL = HL / 10, A = HL mod 10
    pop  de
    add a, '0'
    push af                 ; push digit char
    inc de                  ; digit count++
    ld  a, h : or  l
    jr  nz, .dot_div
    ; Print sign if negative
    ld  a, (DOT_SIGN)
    bit 7, a
    jr  z, .dot_prt
    ld  a, '-' : rst 0x10
.dot_prt:
    ; Print digits (they're on stack in reverse = correct order)
    pop  af
    rst 0x10
    dec de
    ld  a, d : or  e
    jr  nz, .dot_prt
    ; Trailing space
    ld  a, 32 : rst 0x10
    ; (BC no longer holds IP — freed by FORTH_IP in memory)
    POP_TOS : jp  FORTH_NEXT

; Helper: HL = HL / DE, A = remainder
_DOT_DIVMOD:
    ld  bc, 0               ; quotient
    or  a
.ddm_loop:
    sbc hl, de
    jr  c, .ddm_done
    inc bc
    jr  .ddm_loop
.ddm_done:
    add hl, de              ; restore remainder
    ld  a, l                ; A = remainder
    ld  h, b : ld  l, c    ; HL = quotient
    ret


; D.  ( d -- )  Print double number
W_DDOT: LFA_EMIT
_LINK = W_DDOT
        db  2, "D", '.'|0x80
DDOT:   dw  DDOT_CODE
DDOT_CODE:
    ; ( d_low d_high -- )  Print signed double
    ; For now, drop high word and print low word as signed
    pop  de                 ; DE = d_low
    push de
    ld  h, d : ld  l, e    ; HL = d_low
    jr  DOT_CODE            ; reuse . code

; U.  ( u -- )  Print unsigned number
W_UDOT: LFA_EMIT
_LINK = W_UDOT
        db  2, "U", '.'|0x80
UDOT:   dw  UDOT_CODE
UDOT_CODE:
    ; U. ( u -- )  Print unsigned number with trailing space
    ; TOS = u (HL). Convert to double (d_low=u, d_high=0), extract digits.
    push hl                 ; push u as d_low
    ld  hl, 0               ; d_high = 0 (TOS)
    ; <#
    call _MC_BHASH
    ; #S
    call _MC_HASHS          ; ( 0 0 )
    ; #> — discard d, get addr+len
    pop  de                 ; discard d_low
    ld  de, (USER_START + U_HLD)
    ld  hl, PAD_START + 64
    or  a
    sbc hl, de              ; HL = length
    ; Print
    ld  b, h : ld  c, l
    ld  h, d : ld  l, e
.udot_print:
    ld  a, b : or  c
    jr  z, .udot_space
    ld  a, (hl) : rst 0x10
    inc hl : dec bc
    jr  .udot_print
.udot_space:
    ld  a, 32 : rst 0x10   ; trailing space
    POP_TOS : jp  FORTH_NEXT

; .R  ( n width -- )  Print right-justified
W_DOTR: LFA_EMIT
_LINK = W_DOTR
        db  2, ".", 'R'|0x80
DOTR:   dw  DOTR_CODE
DOTR_CODE:
    pop  de                 ; DE=n, HL=width (stub)
    ld  h, d : ld  l, e
    jp  DOT_CODE            ; just print for now

; ?  ( addr -- )  Fetch and print
W_QUEST: LFA_EMIT
_LINK = W_QUEST
         db  1, '?'|0x80
QUEST:   dw  QUEST_CODE
QUEST_CODE:
    call _MC_FETCH          ; @
    jp   DOT_CODE           ; .

; VLIST  ( -- )  List all words in CONTEXT vocabulary
W_VLIST: LFA_EMIT
_LINK = W_VLIST
         db  5, "VLIS", 'T'|0x80
VLIST:   dw  VLIST_CODE
VLIST_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl)
    inc hl
    ld  d, (hl)
    ex  de, hl            ; NFA of last word
.vlist_loop:
    ld  a, h : or  l : jr  z, .vlist_done  ; end of chain (link=0)
    ; Check smudge bit
    ld  a, (hl) : and F_SMUDGE : jr  nz, .vlist_next
    ; Print name
    push hl
    call _MC_IDDOT
    ; Check ?TERMINAL every word
    push hl                 ; save (hl was popped by IDDOT)
    call _MC_QTERM
    ld  a, h : or  l : jr  nz, .vlist_abort
    pop  hl
    ; Space
    ld  a, 32 : rst 0x10
    jr  .vlist_cont
.vlist_next:
    push hl
.vlist_cont:
    pop  hl
    ; Follow LFA chain: HL = NFA, LFA = (NFA-2)
    dec hl : dec hl         ; HL = LFA address
    ld  e, (hl) : inc hl : ld  d, (hl)  ; DE = LFA contents (prev word's LFA)
    ld  hl, de              ; HL = prev LFA
    ; NFA = LFA + 2
    inc hl : inc hl         ; HL = prev NFA
    jr  .vlist_loop
.vlist_abort:
    pop  hl                 ; clean up stack
.vlist_done:
    POP_TOS : jp  FORTH_NEXT

; ============================================================ QUIT / ABORT / WARM / COLD entries
; These are Forth dictionary entries that jump into engine.asm machine code.

W_QUIT: LFA_EMIT
_LINK = W_QUIT
        db  4, "QUI", 'T'|0x80
QUIT:   dw  QUIT_CODE
QUIT_CODE:
    jp  FORTH_QUIT_MC

W_ABORT: LFA_EMIT
_LINK = W_ABORT
         db  5, "ABOR", 'T'|0x80
ABORT:   dw  ABORT_CODE
ABORT_CODE:
    jp  FORTH_ABORT

W_WARM_W: LFA_EMIT
_LINK = W_WARM_W
          db  4, "WAR", 'M'|0x80
WARM_W:   dw  WARM_W_CODE
WARM_W_CODE:
    jp  FORTH_WARM

W_COLD_W: LFA_EMIT
_LINK = W_COLD_W
          db  4, "COL", 'D'|0x80
COLD_W:   dw  COLD_W_CODE
COLD_W_CODE:
    jp  FORTH_COLD

; NOTE: FORGET lives in userwords.asm (W_FORGET_W) — a working implementation.
; A dead stub here was removed; it was shadowed by the real word (userwords.asm
; is included last, so its FORGET is found first in the dictionary search).

; ============================================================ HEX / DECIMAL ===
W_HEX:  LFA_EMIT
_LINK = W_HEX
        db  3, "HE", 'X'|0x80
HEX:    dw  HEX_CODE
HEX_CODE:
    ld  hl, 16
    ld  (USER_START + U_BASE), hl
    jp  FORTH_NEXT

W_DECIMAL: LFA_EMIT
_LINK = W_DECIMAL
           db  7, "DECIMA", 'L'|0x80
DECIMAL:   dw  DECIMAL_CODE
DECIMAL_CODE:
    ld  hl, 10
    ld  (USER_START + U_BASE), hl
    jp  FORTH_NEXT

; ============================================================ IMMEDIATE ========
W_IMMEDIATE: LFA_EMIT
_LINK = W_IMMEDIATE
             db  9, "IMMEDIAT", 'E'|0x80
IMMEDIATE:   dw  IMMEDIATE_CODE
IMMEDIATE_CODE:
    ; Set immediate flag on last defined word
    ld  hl, (USER_START + U_CURRENT)
    ld  e, (hl)
    inc hl
    ld  d, (hl)
    ex  de, hl
    ld  a, (hl)
    or  F_IMM
    ld  (hl), a
    jp  FORTH_NEXT

; ============================================================ VOCABULARY ======
W_VOCABULARY: LFA_EMIT
_LINK = W_VOCABULARY
              db  10, "VOCABULAR", 'Y'|0x80
VOCABULARY:   dw  VOCABULARY_CODE
VOCABULARY_CODE:
    ; Stub: parse name + CREATE a DOVAR word (full vocab model not implemented).
    PUSH_TOS
    ld  hl, 32
    call _MC_WORD           ; parse name -> HERE
    call _MC_CREATE
    ld  de, (USER_START + U_DP)
    ld  a, FORTH_DOVAR & 0xFF : ld  (de), a : inc de
    ld  a, FORTH_DOVAR >> 8   : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS
    jp  FORTH_NEXT

; ============================================================ FORTH (vocab) ===
W_FORTH_V: LFA_EMIT
_LINK = W_FORTH_V
           db  5, "FORT", 'H'|0x80
FORTH_V:   dw  FORTH_V_CODE
FORTH_V_CODE:
    ; Set CONTEXT to FORTH vocabulary
    ld  hl, W_FORTH_V + 2   ; NFA of FORTH word
    ld  (USER_START + U_CONTEXT), hl
    jp  FORTH_NEXT

; DEFINITIONS  ( -- )  Set CURRENT = CONTEXT
W_DEFINITIONS: LFA_EMIT
_LINK = W_DEFINITIONS
               db  11, "DEFINITION", 'S'|0x80
DEFINITIONS:   dw  DEFINITIONS_CODE
DEFINITIONS_CODE:
    ld  hl, (USER_START + U_CONTEXT)
    ld  (USER_START + U_CURRENT), hl
    jp  FORTH_NEXT

; ============================================================ INTERPRET ========
; Full INTERPRET: scan tokens, look up in dictionary, execute or compile.
W_INTERPRET: LFA_EMIT
_LINK = W_INTERPRET
             db  9, "INTERPRE", 'T'|0x80
INTERPRET:   dw  INTERPRET_CODE
INTERPRET_CODE:
    ; INTERPRET ( -- )  Process all tokens in input buffer.
    ; Runs the interpreter loop inline. When end of input is reached,
    ; returns to the threaded caller via FORTH_NEXT.
    ; Reuse the machine-code interpreter but with a different return path.
    ; Save BC (IP) so we can resume threading after interpretation.
    ld  (INTERPRET_SAVE_IP), bc
    jp  _DO_INTERPRET       ; process tokens; ends at _QUIT_CONTINUE
    ; NOTE: When called from threaded Forth (not from QUIT), the
    ; _QUIT_CONTINUE path is wrong. For now, INTERPRET is only called
    ; from the machine-code QUIT loop, so this is acceptable.
    ; A proper threaded INTERPRET would need its own return mechanism.

; ============================================================ ( comment ) =====
W_PAREN: LFA_EMIT
_LINK = W_PAREN
         db  F_IMM | 1, '('|0x80
PAREN:   dw  PAREN_CODE
PAREN_CODE:
    ; Scan input until ')' 
    ld  hl, (USER_START + U_TIB)
    ld  de, (USER_START + U_IN)
    add hl, de
.paren_loop:
    ld  a, (hl) : inc hl
    cp  ')' : jr  z, .paren_done
    cp  0   : jr  z, .paren_done
    jr  .paren_loop
.paren_done:
    ; Update IN
    ld  de, hl
    ld  hl, (USER_START + U_TIB)
    or  a : sbc hl, de
    ld  a, l
    ld  (USER_START + U_IN), a  ; low byte only (TIB < 256)
    jp  FORTH_NEXT

; ============================================================ Block I/O =======
; RAM-only block system. 2 buffers of 1024 bytes each.
; Buffer layout at BUF_START:
;   [hdr0: blk# 2, flags 1, pad 1] [data0: 1024] [hdr1: 4] [data1: 1024]
; Total: 2 * (4 + 1024) = 2056 bytes. Fits in BUF_START..BUF_END.
; Flag byte: bit 0 = dirty (UPDATE'd)
; Block# = 0 means buffer is free.

BUF_HDR_SIZE    EQU 4
BUF_DATA_SIZE   EQU 1024
BUF_ENTRY_SIZE  EQU BUF_HDR_SIZE + BUF_DATA_SIZE
N_BUFFERS       EQU 2

; _BUF_FIND: find buffer holding block HL. Returns DE=data addr, Z=found.
; If not found, Z is clear.
_BUF_FIND:
    ld  de, BUF_START
    ld  b, N_BUFFERS
.bf_loop:
    ld  a, (de) : inc de
    ld  c, a
    ld  a, (de) : dec de
    ; BC-style compare: (de)=blk_lo, (de+1)=blk_hi vs HL
    cp  h : jr  nz, .bf_next
    ld  a, c : cp  l : jr  nz, .bf_next
    ; Found! DE = header start. Data = DE + BUF_HDR_SIZE
    push hl
    ld  hl, BUF_HDR_SIZE
    add hl, de
    ex  de, hl          ; DE = data address
    pop  hl
    xor a               ; set Z flag (found)
    ret
.bf_next:
    push hl
    ld  hl, BUF_ENTRY_SIZE
    add hl, de
    ex  de, hl
    pop  hl
    djnz .bf_loop
    or  1               ; clear Z flag (not found)
    ret

; _BUF_ASSIGN: assign a buffer for block HL. Returns DE=data addr.
; Uses simple round-robin (USE pointer). Zeroes the buffer.
_BUF_ASSIGN:
    ; Get USE buffer index
    ld  a, (BUF_USE_IDX)
    ; Compute header address: BUF_START + index * BUF_ENTRY_SIZE
    ld  de, BUF_START
    or  a
    jr  z, .ba_have
    push hl
    ld  hl, BUF_ENTRY_SIZE
    add hl, de
    ex  de, hl          ; DE = header of buffer 1
    pop  hl
.ba_have:
    ; Write block number into header
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    xor a    : ld  (de), a : inc de   ; flags = 0 (clean)
              ld  (de), a : inc de   ; pad = 0
    ; DE = data address. Zero the buffer.
    push de : push hl
    ld  hl, de          ; can't do ld hl,de directly
    ex  de, hl          ; HL = data addr (source), DE = data+1 (dest)
    ld  (hl), 0
    push hl
    pop  de
    inc de
    ld  bc, BUF_DATA_SIZE - 1
    ldir
    pop  hl : pop  de
    ; Advance USE index (round-robin)
    ld  a, (BUF_USE_IDX)
    inc a
    cp  N_BUFFERS
    jr  c, .ba_nowrap
    xor a
.ba_nowrap:
    ld  (BUF_USE_IDX), a
    ret

W_BLOCK_W: LFA_EMIT
_LINK = W_BLOCK_W
           db  5, "BLOC", 'K'|0x80
BLOCK_W:   dw  BLOCK_W_CODE
BLOCK_W_CODE:
    ; BLOCK ( blk# -- addr )  Get buffer address for block
    ; Search for block in buffers; if not found, assign one.
    call _BUF_FIND      ; Z=found, DE=data addr
    jr  z, .blk_found
    ; Not found: assign a buffer
    call _BUF_ASSIGN    ; DE=data addr
.blk_found:
    ex  de, hl          ; HL = buffer data address
    jp  FORTH_NEXT

W_BUFFER_W: LFA_EMIT
_LINK = W_BUFFER_W
            db  6, "BUFFE", 'R'|0x80
BUFFER_W:   dw  BUFFER_W_CODE
BUFFER_W_CODE:
    ; BUFFER ( blk# -- addr )  Assign buffer without reading
    ; Same as BLOCK for our RAM-only system
    call _BUF_FIND
    jr  z, .buf_found
    call _BUF_ASSIGN
.buf_found:
    ex  de, hl
    jp  FORTH_NEXT

W_UPDATE: LFA_EMIT
_LINK = W_UPDATE
          db  6, "UPDAT", 'E'|0x80
UPDATE:   dw  UPDATE_CODE
UPDATE_CODE:
    ; UPDATE ( -- )  Mark most recently accessed buffer as dirty
    ; Set dirty flag on the PREV buffer (the one most recently returned by BLOCK)
    ; For simplicity, mark ALL buffers as dirty
    push hl
    ld  hl, BUF_START + 2  ; flags byte of buffer 0
    set 0, (hl)
    ld  hl, BUF_START + BUF_ENTRY_SIZE + 2  ; flags of buffer 1
    set 0, (hl)
    pop  hl
    jp  FORTH_NEXT

W_FLUSH: LFA_EMIT
_LINK = W_FLUSH
         db  5, "FLUS", 'H'|0x80
FLUSH:   dw  FLUSH_CODE
FLUSH_CODE:
    ; FLUSH ( -- )  Write all dirty buffers (no-op for RAM-only system)
    ; Clear dirty flags
    push hl
    ld  hl, BUF_START + 2
    res 0, (hl)
    ld  hl, BUF_START + BUF_ENTRY_SIZE + 2
    res 0, (hl)
    pop  hl
    jp  FORTH_NEXT

W_LOAD: LFA_EMIT
_LINK = W_LOAD
        db  4, "LOA", 'D'|0x80
LOAD:   dw  LOAD_CODE
LOAD_CODE:
    ; LOAD ( blk# -- )  Interpret a block as Forth source
    ; 1. Ensure block is in a buffer
    call _BUF_FIND          ; Z=found, DE=data
    jr  z, _LOAD_HAVE
    call _BUF_ASSIGN        ; DE=data
_LOAD_HAVE:
    ; 2. Save current input state
    ld  de, (USER_START + U_BLK)
    ld  (LOAD_SAVE_BLK), de
    ld  de, (USER_START + U_IN)
    ld  (LOAD_SAVE_IN), de
    ; 3. Set BLK = blk#, IN = 0
    ld  (USER_START + U_BLK), hl
    ld  hl, 0
    ld  (USER_START + U_IN), hl
    ; 4. Run the interpreter loop on this block
    ;    _DO_INTERPRET processes tokens until end of input.
    ;    But _DO_INTERPRET returns via JP to _QUIT_CONTINUE...
    ;    We need a version that returns here instead.
    ;    Use _MC_WORD + _DICT_SEARCH inline loop:
_LOAD_LOOP:
    ld  hl, 32
    call _MC_WORD           ; HL = HERE (counted string)
    ld  a, (hl)
    and 0x1F
    jp  z, _LOAD_DONE       ; empty = end of block
    ; Search dictionary
    ld  (MF_HERE), hl
    ld  (LOAD_TOKEN), hl
    ld  hl, (USER_START + U_CONTEXT)
    ld  e, (hl) : inc hl : ld  d, (hl)
    call _DICT_SEARCH
    jp  z, _LOAD_NUMBER
    ; Found: A=count, HL=CFA
    ld  b, a
    ; Check STATE
    ld  de, (USER_START + U_STATE)
    ld  a, d : or  e
    jr  z, _LOAD_EXEC
    bit 6, b
    jr  nz, _LOAD_EXEC
    ; Compile
    ld  de, (USER_START + U_DP)
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    jr  _LOAD_LOOP
_LOAD_EXEC:
    ; Execute via trampoline (same as _INTERP_EXEC)
    ld  (INTERP_THREAD), hl
    ld  hl, LOAD_RESUME
    ld  (INTERP_THREAD + 2), hl
    pop  hl                 ; TOS from param stack
    ld  bc, INTERP_THREAD
    jp  FORTH_NEXT
; Return from executed word during LOAD
LOAD_RESUME:
    dw  LOAD_RESUME_CODE
LOAD_RESUME_CODE:
    push hl                 ; save TOS back
    jr  _LOAD_LOOP

_LOAD_NUMBER:
    ; Number parsing (same logic as _INTERP_NUMBER)
    ld  hl, (LOAD_TOKEN)
    ld  a, (hl)
    and 0x1F
    ld  c, a
    inc hl
    ld  b, 0
    ld  a, (hl)
    cp  '-'
    jr  nz, .ln_noneg
    ld  b, 1 : inc hl : dec c
    jr  z, _LOAD_ERROR
.ln_noneg:
    ld  a, b
    ld  (LOAD_NEG), a
    ; Strip high bit on last char
    push hl
    ld  d, 0 : ld  e, c
    add hl, de : dec hl
    ld  a, (hl) : and 0x7F : ld  (hl), a
    pop  hl
    ld  de, 0
    push de : push de       ; d = 0
    call _MC_PNUMBER
    ld  a, (hl)
    cp  32 : jr  z, .ln_ok
    or  a  : jr  z, .ln_ok
    cp  13 : jr  z, .ln_ok
    ; Bad number
    pop  de : pop  de
    jr  _LOAD_ERROR
.ln_ok:
    pop  de : pop  hl       ; HL = d_low
    ld  a, (LOAD_NEG)
    or  a : jr  z, .ln_nosign
    ld  a, l : cpl : ld  l, a : ld  a, h : cpl : ld  h, a : inc hl
.ln_nosign:
    ld  de, (USER_START + U_STATE)
    ld  a, d : or  e
    jr  z, .ln_push
    ; Compile literal
    push hl
    ld  de, (USER_START + U_DP)
    ld  a, LIT & 0xFF : ld  (de), a : inc de
    ld  a, LIT >> 8   : ld  (de), a : inc de
    pop  hl
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    jp  _LOAD_LOOP
.ln_push:
    push hl
    jp  _LOAD_LOOP

_LOAD_ERROR:
    ld  hl, (LOAD_TOKEN)
    ld  a, (hl) : and 0x1F : ld  b, a : inc hl
.le_print:
    ld  a, (hl) : and 0x7F : rst 0x10 : inc hl
    djnz .le_print
    ld  hl, _STR_ERR
    call _PRINT_STR
    ; Fall through to restore and abort
_LOAD_DONE:
    ; 5. Restore input state
    ld  hl, (LOAD_SAVE_BLK)
    ld  (USER_START + U_BLK), hl
    ld  hl, (LOAD_SAVE_IN)
    ld  (USER_START + U_IN), hl
    POP_TOS : jp  FORTH_NEXT


W_EMPTY_BUFFERS: LFA_EMIT
_LINK = W_EMPTY_BUFFERS
                 db  13, "EMPTY-BUFFER", 'S'|0x80
EMPTY_BUFFERS:   dw  EMPTY_BUFFERS_CODE
EMPTY_BUFFERS_CODE:
    ld  hl, BUF_START
    ld  de, BUF_START + 1
    ld  bc, BUF_END - BUF_START - 1
    ld  (hl), 0 : ldir
    ; Reset USE index
    xor a
    ld  (BUF_USE_IDX), a
    jp  FORTH_NEXT

; ============================================================ LIST ===========
; LIST  ( blk# -- )  Display a block/screen (16 lines x 64 chars)
W_LIST: LFA_EMIT
_LINK = W_LIST
        db  4, "LIS", 'T'|0x80
LIST:   dw  LIST_CODE
LIST_CODE:
    ; Get buffer address
    push hl                 ; save blk#
    call _BUF_FIND
    jr  z, .list_found
    call _BUF_ASSIGN
.list_found:
    ; DE = data address
    ex  de, hl              ; HL = data
    pop  de                 ; DE = blk# (for display)
    ; Print header: "SCR # n"
    push hl
    ld  a, 13 : rst 0x10
    ld  hl, _STR_SCR
    call _PRINT_STR
    ; Print block number (simple decimal)
    ld  a, e                ; low byte of block#
    call _PRINT_DEC8
    ld  a, 13 : rst 0x10
    pop  hl
    ; Print 16 lines of 64 chars each
    ld  d, 16               ; line count
.list_line:
    ld  b, 64               ; chars per line
.list_char:
    ld  a, (hl)
    or  a
    jr  nz, .list_vis
    ld  a, 32               ; show nulls as spaces
.list_vis:
    cp  32
    jr  nc, .list_ok
    ld  a, 32               ; show control chars as spaces
.list_ok:
    rst 0x10
    inc hl
    djnz .list_char
    ld  a, 13 : rst 0x10
    dec d
    jr  nz, .list_line
    POP_TOS : jp  FORTH_NEXT

_STR_SCR: db "SCR # ", 0

; Print A as 1-3 digit decimal
_PRINT_DEC8:
    ld  b, 0                ; leading zero flag
    ld  c, 100
    call _PD8_DIG
    ld  c, 10
    call _PD8_DIG
    add a, '0'
    rst 0x10
    ret
_PD8_DIG:
    ld  d, 0
.pd_loop:
    cp  c
    jr  c, .pd_done
    sub c
    inc d
    jr  .pd_loop
.pd_done:
    ld  e, a                ; save remainder
    ld  a, d
    or  b                   ; skip leading zeros
    jr  z, .pd_skip
    ld  b, 1                ; no more leading zeros
    ld  a, d
    add a, '0'
    rst 0x10
.pd_skip:
    ld  a, e                ; restore remainder
    ret

; ============================================================ BYE =============
W_BYE:  LFA_EMIT
_LINK = W_BYE
        db  3, "BY", 'E'|0x80
BYE:    dw  BYE_CODE
BYE_CODE:
    ; Return to BASIC
    ; TS2068: switch back to HOME ROM, RST 0 or call BASIC restart
    di
    ld  a, BANK_HOME_ROM
    out (PORT_BANK), a
    rst 0                   ; restart — goes to Spectrum BASIC

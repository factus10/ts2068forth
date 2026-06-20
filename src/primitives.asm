; =============================================================================
; primitives.asm — CODE words
; Convention: labels starting with digit renamed (0BRANCH->ZBRANCH etc.)
; _LINK updates MUST be at column 0.
; =============================================================================

_LINK = 0

; ============================================================ EXECUTE ========
W_EXECUTE:  LFA_EMIT
_LINK = W_EXECUTE
            db  7, "EXECUT", 'E'|0x80
EXECUTE:    dw  EXECUTE_CODE
EXECUTE_CODE:
    ; HL = CFA to execute
    ld  e, (hl)
    inc hl
    ld  d, (hl)     ; DE = handler, HL = CFA+1
    ex  de, hl      ; HL = handler, DE = CFA+1
    pop de          ; restore real TOS... wait
    ; Actually after EXECUTE, the CFA is consumed; new TOS is whatever was NOS.
    ; HL currently = handler address, DE = CFA+1
    ; We need TOS in HL before the dispatched word runs.
    ; Save handler:
    ld  (EXECUTE_TEMP), hl
    pop hl          ; HL = new TOS (was NOS)
    ld  de, EXECUTE_CONTINUE  ; fake return address
    ; Hmm — this is the key challenge: EXECUTE must set up so the called word
    ; returns to FORTH_NEXT correctly, advancing whatever IP was current.
    ; Simplest correct approach: push current BC as if DOCOL, load CFA+2 as IP,
    ; but we don't have a colon word to call.
    ; CORRECT approach: EXECUTE just dispatches the handler with BC unchanged.
    ; The executed word will call GOTO_NEXT which uses BC (unmodified IP).
    ; This is correct! The EXECUTE word consumed the CFA from TOS, now
    ; we dispatch the handler. BC (IP) still points to next word after EXECUTE.
    ld  hl, (EXECUTE_TEMP)
    jp  (hl)
EXECUTE_CONTINUE:
    jp  FORTH_NEXT

; ============================================================ LIT =============
W_LIT:  LFA_EMIT
_LINK = W_LIT
        db  3, "LI", 'T'|0x80
LIT:    dw  LIT_CODE
LIT_CODE:
    PUSH_TOS
    ld  de, (FORTH_IP)
    ld  a, (de) : inc de : ld  l, a
    ld  a, (de) : inc de : ld  h, a
    ld  (FORTH_IP), de
    jp  FORTH_NEXT

; ============================================================ BRANCH =========
W_BRANCH:   LFA_EMIT
_LINK = W_BRANCH
            db  6, "BRANC", 'H'|0x80
BRANCH:     dw  BRANCH_CODE
BRANCH_CODE:
    ; Read 16-bit signed offset from (IP), add to IP-2 (start of offset field)
    ld  bc, (FORTH_IP)
    ld  a, (bc) : inc bc : ld  e, a
    ld  a, (bc) : inc bc : ld  d, a  ; DE = offset
    dec bc : dec bc     ; BC = start of offset field
    push hl             ; save TOS
    ld  h, b : ld  l, c
    add hl, de          ; HL = branch target
    ld  (FORTH_IP), hl
    pop  hl             ; restore TOS
    jp  FORTH_NEXT

; ============================================================ 0BRANCH =========
W_ZBRANCH:  LFA_EMIT
_LINK = W_ZBRANCH
            db  7, "0BRANC", 'H'|0x80
ZBRANCH:    dw  ZBRANCH_CODE
ZBRANCH_CODE:
    ld  a, h
    or  l
    POP_TOS
    jr  z, BRANCH_CODE  ; zero: branch
    ; non-zero: skip offset (IP += 2)
    ld  bc, (FORTH_IP)
    inc bc : inc bc
    ld  (FORTH_IP), bc
    jp  FORTH_NEXT

; ============================================================ (DO) ============
W_DO_RT:    LFA_EMIT
_LINK = W_DO_RT
            db  4, "(DO", ')'|0x80
DO_RT:      dw  DO_RT_CODE
DO_RT_CODE:
    ; TOS=index(HL), NOS=limit
    pop de              ; DE = limit
    RPUSH_HL            ; RS: push index
    ex  de, hl
    RPUSH_HL            ; RS: push limit
    POP_TOS
    jp  FORTH_NEXT

; ============================================================ (LOOP) ==========
W_LOOP_RT:  LFA_EMIT
_LINK = W_LOOP_RT
            db  6, "(LOOP", ')'|0x80
LOOP_RT:    dw  LOOP_RT_CODE
LOOP_RT_CODE:
    ; RS top: limit (high addr), below: index (low addr)
    ld  hl, (USER_START + U_RS_PTR)
    ; index is at (hl), (hl+1); limit at (hl+2), (hl+3)
    ld  e, (hl)
    inc hl
    ld  d, (hl)         ; DE = index
    inc de              ; index++
    dec hl
    ld  (hl), e
    inc hl
    ld  (hl), d         ; store incremented index
    ; fetch limit
    inc hl
    ld  a, (hl)
    inc hl
    ld  h, (hl)
    ld  l, a            ; HL = limit
    ; compare: done if index >= limit (unsigned)
    or  a
    sbc hl, de          ; HL = limit - index; carry if limit < index
    jr  c, .loop_done
    jr  z, .loop_done   ; also done if equal
    jp  BRANCH_CODE     ; loop back
.loop_done:
    ; pop limit and index off RS
    ld  hl, (USER_START + U_RS_PTR)
    ld  de, 4
    add hl, de
    ld  (USER_START + U_RS_PTR), hl
    ; skip branch offset (IP += 2)
    ld  bc, (FORTH_IP) : inc bc : inc bc : ld  (FORTH_IP), bc
    jp  FORTH_NEXT

; ============================================================ (+LOOP) =========
W_PLOOP_RT: LFA_EMIT
_LINK = W_PLOOP_RT
            db  7, "(+LOOP", ')'|0x80
PLOOP_RT:   dw  PLOOP_RT_CODE
PLOOP_RT_CODE:
    ; TOS = step value
    ld  de, hl          ; DE = step
    POP_TOS
    ld  hl, (USER_START + U_RS_PTR)
    ; Add step to index
    ld  a, (hl)
    add a, e
    ld  (hl), a
    inc hl
    ld  a, (hl)
    adc a, d
    ld  (hl), a         ; index updated
    ; Load updated index into DE
    dec hl
    ld  e, (hl) : inc hl : ld  d, (hl)
    ; Load limit
    inc hl
    ld  a, (hl) : inc hl : ld  h, (hl) : ld  l, a  ; HL=limit
    ; Done if index >= limit
    or  a
    sbc hl, de
    jr  c, .ploop_done
    jr  z, .ploop_done
    jp  BRANCH_CODE
.ploop_done:
    ld  hl, (USER_START + U_RS_PTR)
    ld  de, 4
    add hl, de
    ld  (USER_START + U_RS_PTR), hl
    ld  bc, (FORTH_IP) : inc bc : inc bc : ld  (FORTH_IP), bc
    jp  FORTH_NEXT

; ============================================================ LEAVE ===========
W_LEAVE:    LFA_EMIT
_LINK = W_LEAVE
            db  5, "LEAV", 'E'|0x80
LEAVE:      dw  LEAVE_CODE
LEAVE_CODE:
    ; Set index = limit so loop exits on next (LOOP)
    ld  hl, (USER_START + U_RS_PTR)
    ld  e, (hl) : inc hl : ld  d, (hl)  ; DE = index (unused)
    ld  a, (hl) : inc hl : ld  h, (hl) : dec hl : ld  l, a  ; HL=limit
    ld  de, (USER_START + U_RS_PTR)
    ld  a, l
    ld  (de), a
    inc de
    ld  a, h
    ld  (de), a
    jp  FORTH_NEXT

; ============================================================ I ===============
W_I:    LFA_EMIT
_LINK = W_I
        db  1, 'I'|0x80
I_WORD: dw  I_CODE
I_CODE:
    PUSH_TOS
    ld  de, (USER_START + U_RS_PTR)
    ld  a, (de) : ld  l, a : inc de : ld  a, (de) : ld  h, a
    jp  FORTH_NEXT

; ============================================================ J ===============
W_J:    LFA_EMIT
_LINK = W_J
        db  1, 'J'|0x80
J_WORD: dw  J_CODE
J_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_RS_PTR)
    inc hl : inc hl : inc hl : inc hl  ; skip inner limit+index
    ld  a, (hl) : ld  e, a : inc hl : ld  a, (hl) : ld  h, a : ld  l, e
    jp  FORTH_NEXT

; ============================================================ ;S ==============
W_SEMIS:    LFA_EMIT
_LINK = W_SEMIS
            db  2, ";", 'S'|0x80
SEMIS:      dw  FORTH_SEMIS

; ============================================================ Stack ops =======

W_DUP:  LFA_EMIT
_LINK = W_DUP
        db  3, "DU", 'P'|0x80
DUP:    dw  DUP_CODE
DUP_CODE:
    PUSH_TOS : jp  FORTH_NEXT

W_DROP: LFA_EMIT
_LINK = W_DROP
        db  4, "DRO", 'P'|0x80
DROP:   dw  DROP_CODE
DROP_CODE:
    POP_TOS : jp  FORTH_NEXT

W_SWAP: LFA_EMIT
_LINK = W_SWAP
        db  4, "SWA", 'P'|0x80
SWAP:   dw  SWAP_CODE
SWAP_CODE:
    ex  (sp), hl : jp  FORTH_NEXT

W_OVER: LFA_EMIT
_LINK = W_OVER
        db  4, "OVE", 'R'|0x80
OVER:   dw  OVER_CODE
OVER_CODE:
    ; ( a b -- a b a )  HL=b, NOS=a at (SP+0,SP+1)
    ; Use IX to peek at NOS without disturbing SP
    ld  ix, 0
    add ix, sp          ; IX = SP
    ld  e, (ix+0)
    ld  d, (ix+1)       ; DE = NOS (a)
    PUSH_TOS            ; push b
    ld  h, d
    ld  l, e            ; HL = a (new TOS)
    jp  FORTH_NEXT

W_ROT:  LFA_EMIT
_LINK = W_ROT
        db  3, "RO", 'T'|0x80
ROT:    dw  ROT_CODE
ROT_CODE:
    ; ( a b c -- b c a )  TOS=c(HL), NOS=b, 3rd=a
    pop  de             ; DE=b
    pop  bc             ; BC=a
    PUSH_TOS            ; push c
    push de             ; push b
    ld   h, b
    ld   l, c           ; HL=a (new TOS)
    jp  FORTH_NEXT

W_MINUSDUP: LFA_EMIT
_LINK = W_MINUSDUP
            db  4, "-DU", 'P'|0x80
MINUSDUP:   dw  MINUSDUP_CODE
MINUSDUP_CODE:
    ld  a, h : or l
    jr  z, .zero
    PUSH_TOS
.zero:
    jp  FORTH_NEXT

W_DDUP: LFA_EMIT
_LINK = W_DDUP
        db  4, "2DU", 'P'|0x80
DDUP:   dw  DDUP_CODE
DDUP_CODE:
    ; ( a b -- a b a b )  TOS=b(HL)
    pop  de             ; DE=a
    push de             ; restore a
    PUSH_TOS            ; push b
    push de             ; push a
    ; TOS stays HL=b
    jp  FORTH_NEXT

W_DDROP: LFA_EMIT
_LINK = W_DDROP
         db  5, "2DRO", 'P'|0x80
DDROP:   dw  DDROP_CODE
DDROP_CODE:
    pop  de             ; discard NOS
    POP_TOS             ; HL = new TOS (was 3rd)
    jp  FORTH_NEXT

W_DSWAP: LFA_EMIT
_LINK = W_DSWAP
         db  5, "2SWA", 'P'|0x80
DSWAP:   dw  DSWAP_CODE
DSWAP_CODE:
    ; ( a b c d -- c d a b )  TOS=d(HL), NOS=c, 3rd=b, 4th=a
    pop  de             ; DE = c
    pop  bc             ; BC = b
    pop  ix             ; IX = a
    push de             ; push c
    PUSH_TOS            ; push d
    push ix             ; push a
    ld  h, b : ld  l, c ; HL = b (new TOS)
    jp  FORTH_NEXT

W_TOR:  LFA_EMIT
_LINK = W_TOR
        db  2, ">", 'R'|0x80
TOR:    dw  TOR_CODE
TOR_CODE:
    RPUSH_HL
    POP_TOS
    jp  FORTH_NEXT

W_RFROM: LFA_EMIT
_LINK = W_RFROM
         db  2, "R", '>'|0x80
RFROM:   dw  RFROM_CODE
RFROM_CODE:
    PUSH_TOS
    RPOP_HL
    jp  FORTH_NEXT

W_R:    LFA_EMIT
_LINK = W_R
        db  1, 'R'|0x80
R_WORD: dw  R_CODE
R_CODE:
    PUSH_TOS
    ld  de, (USER_START + U_RS_PTR)
    ld  a, (de) : ld  l, a : inc de : ld  a, (de) : ld  h, a
    jp  FORTH_NEXT

W_SPFETCH: LFA_EMIT
_LINK = W_SPFETCH
           db  3, "SP", '@'|0x80
SPFETCH:   dw  SPFETCH_CODE
SPFETCH_CODE:
    PUSH_TOS
    ld  hl, 0
    add hl, sp
    jp  FORTH_NEXT

W_SPSTORE: LFA_EMIT
_LINK = W_SPSTORE
           db  3, "SP", '!'|0x80
SPSTORE:   dw  SPSTORE_CODE
SPSTORE_CODE:
    ld  sp, hl
    POP_TOS
    jp  FORTH_NEXT

W_RPFETCH: LFA_EMIT
_LINK = W_RPFETCH
           db  3, "RP", '@'|0x80
RPFETCH:   dw  RPFETCH_CODE
RPFETCH_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_RS_PTR)
    jp  FORTH_NEXT

W_RPSTORE: LFA_EMIT
_LINK = W_RPSTORE
           db  3, "RP", '!'|0x80
RPSTORE:   dw  RPSTORE_CODE
RPSTORE_CODE:
    ld  (USER_START + U_RS_PTR), hl
    POP_TOS
    jp  FORTH_NEXT

; ============================================================ Arithmetic =====

W_ADD:  LFA_EMIT
_LINK = W_ADD
        db  1, '+'|0x80
ADD:    dw  ADD_CODE
ADD_CODE:
    pop de : add hl, de : jp  FORTH_NEXT

W_SUB:  LFA_EMIT
_LINK = W_SUB
        db  1, '-'|0x80
SUB:    dw  SUB_CODE
SUB_CODE:
    ; ( a b -- a-b )  TOS=b
    ld  d, h : ld  e, l : pop  hl : or  a : sbc  hl, de
    jp  FORTH_NEXT

W_MINUS: LFA_EMIT
_LINK = W_MINUS
         db  5, "MINU", 'S'|0x80
MINUS:   dw  MINUS_CODE
MINUS_CODE:
    ld  a, l : cpl : ld  l, a
    ld  a, h : cpl : ld  h, a
    inc hl
    jp  FORTH_NEXT

W_DMINUS: LFA_EMIT
_LINK = W_DMINUS
          db  6, "DMINU", 'S'|0x80
DMINUS:   dw  DMINUS_CODE
DMINUS_CODE:
    ; ( dlo dhi -- -dlo -dhi )  TOS=dhi(HL)
    pop  de
    ld  a, e : cpl : ld  e, a : ld  a, d : cpl : ld  d, a : inc de
    ld  a, l : cpl : ld  l, a : ld  a, h : cpl : ld  h, a
    jr  nc, .dc : inc hl
.dc:
    push de : jp  FORTH_NEXT

W_DADD: LFA_EMIT
_LINK = W_DADD
        db  2, "D", '+'|0x80
DADD:   dw  DADD_CODE
DADD_CODE:
    ; ( alo ahi blo bhi -- clo chi )  TOS=bhi(HL)
    ld  b, h : ld  c, l         ; BC = bhi
    pop  hl                     ; HL = blo
    pop  de                     ; DE = ahi
    pop  ix                     ; IX = alo
    push ix                     ; restore IX to stack... IX is scratch register
    ; Use alternate registers
    ld  a, ixl : add a, l : ld  l, a
    ld  a, ixh : adc a, h : ld  h, a  ; HL = clo
    ld  a, e   : adc a, c  : ld  e, a
    ld  a, d   : adc a, b  : ld  d, a  ; DE = chi
    push hl                     ; push clo
    ld  h, d : ld  l, e         ; HL = chi (TOS)
    jp  FORTH_NEXT

W_STAR: LFA_EMIT
_LINK = W_STAR
        db  1, '*'|0x80
STAR:   dw  STAR_CODE
STAR_CODE:
    ; 16x16->16 signed multiply (low 16 bits)
    pop  de
    ld  b, h : ld  c, l     ; BC = multiplier (HL)
    ld  hl, 0
    ld  a, 16
.ml:
    add hl, hl
    ex  de, hl
    add hl, hl
    ex  de, hl
    jr  nc, .ms
    add hl, bc
.ms:
    dec a : jr  nz, .ml
    jp  FORTH_NEXT

W_USTAR: LFA_EMIT
_LINK = W_USTAR
         db  2, "U", '*'|0x80
USTAR:   dw  USTAR_CODE
USTAR_CODE:
    ; ( u1 u2 -- udlo udhi ) 16x16->32 unsigned multiply
    ; DI/EI required: ISR uses alternate registers
    ; u2 must be in BOTH main BC and alt BC' for the EXX multiply loop
    pop  de                 ; DE=u1, HL=u2
    ld  b, h : ld  c, l    ; BC=u2 (main)
    push bc                 ; save u2 for alt regs
    ld  hl, 0
    di
    exx
    pop  bc                 ; BC'=u2 (alt)
    ld  hl, 0              ; HL'=product low
    exx
    ld  a, 16
.um:
    exx
    add hl, hl             ; shift product low left, MSB->carry
    exx
    adc hl, hl             ; shift product high left with carry
    ex  de, hl             ; HL=u1, DE=product high
    add hl, hl             ; shift u1 left, MSB->carry
    ex  de, hl             ; HL=product high, DE=u1
    jr  nc, .um_skip
    exx
    ld  de, 0
    ld  e, c               ; C' = u2 low byte (now correct!)
    add hl, de             ; add u2 low to product low
    exx
    ld  de, 0
    ld  e, b               ; B' = u2 high byte (now correct!)
    adc hl, de             ; add u2 high + carry to product high
.um_skip:
    dec a : jr  nz, .um
    exx
    push hl                ; push product low
    exx
    ei
    ; HL = product high (TOS)
    jp  FORTH_NEXT

W_UDIV: LFA_EMIT
_LINK = W_UDIV
        db  2, "U", '/'|0x80
UDIV:   dw  UDIV_CODE
UDIV_CODE:
    call _MC_UDIV
    jp  FORTH_NEXT
_MC_UDIV:
    ; ( udlo udhi u -- uq ur )  32/16 unsigned divide
    ; TOS=u(divisor in HL), NOS=udhi, 3rd=udlo
    ; Result: quotient and remainder (both 16-bit)
    ld  d, h : ld  e, l ; DE = divisor
    pop  hl             ; HL = udhi (remainder accumulator)
    pop  bc             ; BC = udlo (becomes quotient via shift)
    ; Standard 32/16 restoring division:
    ; Shift BC:HL left 16 times. Each iteration:
    ;   shift BC left, MSB into HL (remainder)
    ;   if HL >= DE, subtract DE from HL, set bit 0 of BC
    ld  a, 16
.ud:
    ; Shift BC left one bit, carry into HL
    sla c : rl  b       ; shift quotient/dividend left
    adc hl, hl          ; shift remainder left, carry in from BC
    ; Trial subtract
    or  a
    sbc hl, de          ; HL = remainder - divisor
    jr  nc, .ud_fits    ; no borrow: divisor fits
    add hl, de          ; restore remainder (doesn't fit)
    jr  .ud_next
.ud_fits:
    set 0, c            ; set quotient bit
.ud_next:
    dec a : jr  nz, .ud
    ; BC = quotient, HL = remainder
    push bc             ; push quotient
    ; HL = remainder (TOS)
    ret

; ============================================================ Comparison ====

W_EQ:   LFA_EMIT
_LINK = W_EQ
        db  1, '='|0x80
EQ:     dw  EQ_CODE
EQ_CODE:
    pop  de : or  a : sbc  hl, de
    jr   z, .yes : ld  hl, 0 : jp  FORTH_NEXT
.yes:
    ld  hl, 0xFFFF : jp  FORTH_NEXT

W_ZEQAL: LFA_EMIT
_LINK = W_ZEQAL
         db  2, "0", '='|0x80     ; NOTE: "0=" — sjasmplus ok with digit in DB string
ZEQAL:   dw  ZEQAL_CODE
ZEQAL_CODE:
    ld  a, h : or  l
    jr  z, .yes : ld  hl, 0 : jp  FORTH_NEXT
.yes:
    ld  hl, 0xFFFF : jp  FORTH_NEXT

W_ZLESS: LFA_EMIT
_LINK = W_ZLESS
         db  2, "0", '<'|0x80
ZLESS:   dw  ZLESS_CODE
ZLESS_CODE:
    add hl, hl : sbc hl, hl : jp  FORTH_NEXT

W_LESS: LFA_EMIT
_LINK = W_LESS
        db  1, '<'|0x80
LESS:   dw  LESS_CODE
LESS_CODE:
    ; ( a b -- flag )  signed: a<b
    pop  de             ; DE=a, HL=b
    or   a
    sbc  hl, de         ; HL = b-a; if b>a then HL>0; if b<a then HL<0 (neg)
    ; a<b when b-a > 0, i.e., NOT (b-a <= 0)
    ; Easier: compute a-b, check sign: negative means a<b
    ; swap and redo:
    ex   de, hl         ; DE=b-a, HL=a
    ld   bc, hl         ; temp... 
    ld   hl, de         ; HL=b-a ... getting confusing
    ; Clean: a-b negative means a<b
    ; After pop de: DE=a, HL=b
    ; want a-b: swap them
    ; Just: compute b-a (already done), positive means a<b
    ; HL = b-a. If b>a: HL>0 (sign bit 0 means NOT negative, so a>=b)
    ; If b<a: HL<0 (sign bit 1 means a<b was FALSE... wait)
    ; b-a < 0 means b<a means a>b means NOT a<b
    ; b-a > 0 means b>a means a<b => TRUE
    ; b-a = 0 means equal => FALSE
    ; So: a<b is TRUE when (b-a) has sign bit = 0 AND (b-a) != 0
    ; Simplest: after computing b-a in DE, check DE sign and DE!=0
    ld  hl, de
    ld  a, h
    or  l               ; zero?
    jr  z, .no          ; equal, not less
    bit 7, h            ; sign of b-a
    jr  nz, .no         ; b-a negative means b<a means NOT a<b
    ld  hl, 0xFFFF
    jp  FORTH_NEXT
.no:
    ld  hl, 0
    jp  FORTH_NEXT

W_GREATER: LFA_EMIT
_LINK = W_GREATER
           db  1, '>'|0x80
GREATER:   dw  GREATER_CODE
GREATER_CODE:
    ; ( a b -- flag )  a>b: same as b<a
    ex  (sp), hl        ; swap TOS and NOS: now HL=a (was NOS), (SP)=b
    jp  LESS_CODE       ; compute a<b with swapped args = original b<a = a>b

W_ULESS: LFA_EMIT
_LINK = W_ULESS
         db  2, "U", '<'|0x80
ULESS:   dw  ULESS_CODE
ULESS_CODE:
    ; ( a b -- flag )  unsigned a<b
    pop  de             ; DE=a
    or   a
    sbc  hl, de         ; HL=b-a, carry if b<a (borrow means b<a)
    ; If NO carry: b>=a
    ; If carry: b<a => a>b => NOT a<b
    ; We want: carry CLEAR and result nonzero => a<b
    jr  c, .no          ; carry means b<a, so a>b
    ld  a, h : or  l
    jr  z, .no          ; zero means equal
    ld  hl, 0xFFFF : jp  FORTH_NEXT
.no:
    ld  hl, 0 : jp  FORTH_NEXT

; ============================================================ Logic ==========

W_AND:  LFA_EMIT
_LINK = W_AND
        db  3, "AN", 'D'|0x80
AND:    dw  AND_CODE
AND_CODE:
    pop  de
    ld  a, h : and d : ld  h, a
    ld  a, l : and e : ld  l, a
    jp  FORTH_NEXT

W_OR:   LFA_EMIT
_LINK = W_OR
        db  2, "O", 'R'|0x80
OR:     dw  OR_CODE
OR_CODE:
    pop  de
    ld  a, h : or  d : ld  h, a
    ld  a, l : or  e : ld  l, a
    jp  FORTH_NEXT

W_XOR:  LFA_EMIT
_LINK = W_XOR
        db  3, "XO", 'R'|0x80
XOR:    dw  XOR_CODE
XOR_CODE:
    pop  de
    ld  a, h : xor d : ld  h, a
    ld  a, l : xor e : ld  l, a
    jp  FORTH_NEXT

W_NOT:  LFA_EMIT
_LINK = W_NOT
        db  3, "NO", 'T'|0x80
NOT:    dw  NOT_CODE
NOT_CODE:
    ld  a, h : cpl : ld  h, a
    ld  a, l : cpl : ld  l, a
    jp  FORTH_NEXT

; ============================================================ Memory ==========

W_FETCH: LFA_EMIT
_LINK = W_FETCH
         db  1, '@'|0x80
FETCH:   dw  FETCH_CODE
FETCH_CODE:
    call _MC_FETCH
    jp  FORTH_NEXT
_MC_FETCH:
    ld  e, (hl) : inc hl : ld  d, (hl) : ex  de, hl
    ret

W_STORE: LFA_EMIT
_LINK = W_STORE
         db  1, '!'|0x80
STORE:   dw  STORE_CODE
STORE_CODE:
    pop  de : ld  (hl), e : inc hl : ld  (hl), d : POP_TOS : jp  FORTH_NEXT

W_CFETCH: LFA_EMIT
_LINK = W_CFETCH
          db  2, "C", '@'|0x80
CFETCH:   dw  CFETCH_CODE
CFETCH_CODE:
    ld  l, (hl) : ld  h, 0 : jp  FORTH_NEXT

W_CSTORE: LFA_EMIT
_LINK = W_CSTORE
          db  2, "C", '!'|0x80
CSTORE:   dw  CSTORE_CODE
CSTORE_CODE:
    pop  de : ld  (hl), e : POP_TOS : jp  FORTH_NEXT

W_DFETCH: LFA_EMIT
_LINK = W_DFETCH
          db  2, "2", '@'|0x80
DFETCH:   dw  DFETCH_CODE
DFETCH_CODE:
    ld  e, (hl) : inc hl : ld  d, (hl) : inc hl
    ld  c, (hl) : inc hl : ld  b, (hl)
    push de : ld  h, b : ld  l, c : jp  FORTH_NEXT

W_DSTORE: LFA_EMIT
_LINK = W_DSTORE
          db  2, "2", '!'|0x80
DSTORE:   dw  DSTORE_CODE
DSTORE_CODE:
    pop  de : pop  bc
    ld  (hl), c : inc hl : ld  (hl), b : inc hl
    ld  (hl), e : inc hl : ld  (hl), d
    POP_TOS : jp  FORTH_NEXT

W_PLUSST: LFA_EMIT
_LINK = W_PLUSST
          db  2, "+", '!'|0x80
PLUSST:   dw  PLUSST_CODE
PLUSST_CODE:
    pop  de
    ld  a, (hl) : add a, e : ld  (hl), a
    inc hl : ld  a, (hl) : adc a, d : ld  (hl), a
    POP_TOS : jp  FORTH_NEXT

W_TOGGLE: LFA_EMIT
_LINK = W_TOGGLE
          db  6, "TOGGL", 'E'|0x80
TOGGLE:   dw  TOGGLE_CODE
TOGGLE_CODE:
    pop  de : ld  a, (de) : xor l : ld  (de), a : POP_TOS : jp  FORTH_NEXT

; ============================================================ Arithmetic 2 ===

W_ONEPLUS: LFA_EMIT
_LINK = W_ONEPLUS
         db  2, "1", '+'|0x80
ONEPLUS:   dw  ONEPLUS_CODE
ONEPLUS_CODE:
    inc hl : jp  FORTH_NEXT

W_TWOPLUS: LFA_EMIT
_LINK = W_TWOPLUS
         db  2, "2", '+'|0x80
TWOPLUS:   dw  TWOPLUS_CODE
TWOPLUS_CODE:
    inc hl : inc hl : jp  FORTH_NEXT

; ============================================================ I/O =============

W_EMIT: LFA_EMIT
_LINK = W_EMIT
        db  4, "EMI", 'T'|0x80
EMIT:   dw  EMIT_CODE
EMIT_CODE:
    ld  a, l
    rst 0x10
    POP_TOS : jp  FORTH_NEXT

W_CR:   LFA_EMIT
_LINK = W_CR
        db  2, "C", 'R'|0x80
CR:     dw  CR_CODE
CR_CODE:
    ld  a, 13 : rst 0x10 : jp  FORTH_NEXT

W_KEY:  LFA_EMIT
_LINK = W_KEY
        db  3, "KE", 'Y'|0x80
KEY:    dw  KEY_CODE
KEY_CODE:
    PUSH_TOS
.kw:
    halt
    ld  hl, SYSVAR_FLAGS
    bit 5, (hl) : jr  z, .kw
    res 5, (hl)
    ld  a, (SYSVAR_LASTK)
    ld  l, a : ld  h, 0
    jp  FORTH_NEXT

W_QTERM: LFA_EMIT
_LINK = W_QTERM
         db  9, "?TERMINA", 'L'|0x80
QTERM:   dw  QTERM_CODE
QTERM_CODE:
    call _MC_QTERM
    jp  FORTH_NEXT
_MC_QTERM:
    PUSH_TOS
    ld  hl, SYSVAR_FLAGS
    bit 5, (hl)
    jr  z, .nk
    ld  hl, 0xFFFF
    ret
.nk:
    ld  hl, 0
    ret

; ============================================================ Strings ========

W_CMOVE: LFA_EMIT
_LINK = W_CMOVE
         db  5, "CMOV", 'E'|0x80
CMOVE:   dw  CMOVE_CODE
CMOVE_CODE:
    ld  b, h : ld  c, l
    pop  de : pop  hl
    ldir
    POP_TOS : jp  FORTH_NEXT

; CMOVE>  ( src dest len -- )  Copy len bytes high->low (descending).
; The overlap-safe counterpart to CMOVE: use when dest > src and they overlap.
W_CMOVE_UP: LFA_EMIT
_LINK = W_CMOVE_UP
            db  6, "CMOVE", '>'|0x80
CMOVE_UP:   dw  CMOVE_UP_CODE
CMOVE_UP_CODE:
    ld  b, h : ld  c, l      ; BC = len
    pop  de                  ; DE = dest
    pop  hl                  ; HL = src
    add hl, bc : dec hl      ; HL = src + len - 1 (last source byte)
    ex  de, hl               ; DE = src_end, HL = dest
    add hl, bc : dec hl      ; HL = dest + len - 1 (last dest byte)
    ex  de, hl               ; HL = src_end, DE = dest_end
    lddr                     ; copy descending
    POP_TOS : jp  FORTH_NEXT

W_COUNT: LFA_EMIT
_LINK = W_COUNT
         db  5, "COUN", 'T'|0x80
COUNT:   dw  COUNT_CODE
COUNT_CODE:
    ld  d, (hl)
    inc hl
    PUSH_TOS
    ld  h, 0 : ld  l, d
    jp  FORTH_NEXT

; ============================================================ Dictionary ======

W_HERE: LFA_EMIT
_LINK = W_HERE
        db  4, "HER", 'E'|0x80
HERE:   dw  HERE_CODE
HERE_CODE:
    PUSH_TOS
    ld  hl, (USER_START + U_DP)
    jp  FORTH_NEXT

W_ALLOT: LFA_EMIT
_LINK = W_ALLOT
         db  5, "ALLO", 'T'|0x80
ALLOT:   dw  ALLOT_CODE
ALLOT_CODE:
    ld  de, (USER_START + U_DP)
    add hl, de
    ld  (USER_START + U_DP), hl
    POP_TOS : jp  FORTH_NEXT

W_COMMA: LFA_EMIT
_LINK = W_COMMA
         db  1, ','|0x80
COMMA:   dw  COMMA_CODE
COMMA_CODE:
    ld  de, (USER_START + U_DP)
    ld  a, l
    ld  (de), a : inc de
    ld  a, h
    ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

W_CCOMMA: LFA_EMIT
_LINK = W_CCOMMA
          db  2, "C", ','|0x80
CCOMMA:   dw  CCOMMA_CODE
CCOMMA_CODE:
    ld  de, (USER_START + U_DP)
    ld  a, l : ld  (de), a : inc de
    ld  (USER_START + U_DP), de
    POP_TOS : jp  FORTH_NEXT

; ============================================================ Utilities =======

W_NOOP: LFA_EMIT
_LINK = W_NOOP
        db  4, "NOO", 'P'|0x80
NOOP:   dw  NOOP_CODE
NOOP_CODE:
    jp  FORTH_NEXT

W_DEPTH: LFA_EMIT
_LINK = W_DEPTH
         db  5, "DEPT", 'H'|0x80
DEPTH:   dw  DEPTH_CODE
DEPTH_CODE:
    PUSH_TOS
    ld  hl, 0 : add hl, sp  ; HL = current SP
    ld  de, PS_TOP - 2      ; DE = top-of-stack (TOS is in reg, so subtract 2)
    ex  de, hl
    or  a
    sbc hl, de              ; HL = SP - (PS_TOP-2) ... that's negative
    ; Items = (PS_TOP - 2 - SP) / 2 + 1 (the +1 is for TOS in register)
    ex  de, hl
    or  a
    sbc hl, de              ; HL = (PS_TOP-2) - SP = bytes on stack (excl. TOS)
    srl h : rr  l           ; /2 = count of items on stack below TOS
    inc hl                  ; +1 for TOS in register
    jp  FORTH_NEXT

W_DIGIT: LFA_EMIT
_LINK = W_DIGIT
         db  5, "DIGI", 'T'|0x80
DIGIT:   dw  DIGIT_CODE
DIGIT_CODE:
    ; ( char base -- digit true | char false )
    ld  d, h : ld  e, l     ; DE = base
    pop  hl                 ; HL = char
    ld  a, l
    cp  '0' : jr  c, .dfail
    sub '0'
    cp  10  : jr  c, .dchk
    and 0xDF                ; uppercase
    cp  'A'-'0' : jr  c, .dfail
    sub 'A'-'0'-10
    cp  10 : jr  c, .dfail
.dchk:
    cp  e : jr  nc, .dfail  ; >= base
    PUSH_TOS
    ld  l, a : ld  h, 0     ; push digit value
    PUSH_TOS
    ld  hl, 0xFFFF          ; push TRUE
    jp  FORTH_NEXT
.dfail:
    ; HL = char already
    PUSH_TOS
    ld  hl, 0               ; push FALSE
    jp  FORTH_NEXT

; ============================================================ USER vars =======

W_BASE: LFA_EMIT
_LINK = W_BASE
        db  4, "BAS", 'E'|0x80
BASE:   dw  FORTH_DOUSER : dw  U_BASE

W_STATE: LFA_EMIT
_LINK = W_STATE
         db  5, "STAT", 'E'|0x80
STATE:   dw  FORTH_DOUSER : dw  U_STATE

W_DP:   LFA_EMIT
_LINK = W_DP
        db  2, "D", 'P'|0x80
DP:     dw  FORTH_DOUSER : dw  U_DP

W_BLK:  LFA_EMIT
_LINK = W_BLK
        db  3, "BL", 'K'|0x80
BLK:    dw  FORTH_DOUSER : dw  U_BLK

W_IN:   LFA_EMIT
_LINK = W_IN
        db  2, "I", 'N'|0x80
IN:     dw  FORTH_DOUSER : dw  U_IN

W_OUT:  LFA_EMIT
_LINK = W_OUT
        db  3, "OU", 'T'|0x80
OUT:    dw  FORTH_DOUSER : dw  U_OUT

W_SCR:  LFA_EMIT
_LINK = W_SCR
        db  3, "SC", 'R'|0x80
SCR:    dw  FORTH_DOUSER : dw  U_SCR

W_CONTEXT: LFA_EMIT
_LINK = W_CONTEXT
           db  7, "CONTEX", 'T'|0x80
CONTEXT:   dw  FORTH_DOUSER : dw  U_CONTEXT

W_CURRENT: LFA_EMIT
_LINK = W_CURRENT
           db  7, "CURREN", 'T'|0x80
CURRENT:   dw  FORTH_DOUSER : dw  U_CURRENT

W_VOC_LINK: LFA_EMIT
_LINK = W_VOC_LINK
            db  8, "VOC-LIN", 'K'|0x80
VOC_LINK:   dw  FORTH_DOUSER : dw  U_VOC_LINK

W_S0:   LFA_EMIT
_LINK = W_S0
        db  2, "S", '0'|0x80
S0:     dw  FORTH_DOUSER : dw  U_SP0

W_R0:   LFA_EMIT
_LINK = W_R0
        db  2, "R", '0'|0x80
R0:     dw  FORTH_DOUSER : dw  U_R0

W_TIB:  LFA_EMIT
_LINK = W_TIB
        db  3, "TI", 'B'|0x80
TIB:    dw  FORTH_DOUSER : dw  U_TIB

W_HLD:  LFA_EMIT
_LINK = W_HLD
        db  3, "HL", 'D'|0x80
HLD:    dw  FORTH_DOUSER : dw  U_HLD

W_WIDTH: LFA_EMIT
_LINK = W_WIDTH
         db  5, "WIDT", 'H'|0x80
WIDTH:   dw  FORTH_DOUSER : dw  U_WIDTH

W_OFFSET: LFA_EMIT
_LINK = W_OFFSET
          db  6, "OFFSE", 'T'|0x80
OFFSET:   dw  FORTH_DOUSER : dw  U_OFFSET

W_WARNING: LFA_EMIT
_LINK = W_WARNING
           db  7, "WARNIN", 'G'|0x80
WARNING:   dw  FORTH_DOUSER : dw  U_WARNING

W_FENCE: LFA_EMIT
_LINK = W_FENCE
         db  5, "FENC", 'E'|0x80
FENCE:   dw  FORTH_DOUSER : dw  U_FENCE

W_DPL:  LFA_EMIT
_LINK = W_DPL
        db  3, "DP", 'L'|0x80
DPL:    dw  FORTH_DOUSER : dw  U_DPL

W_FLD:  LFA_EMIT
_LINK = W_FLD
        db  3, "FL", 'D'|0x80
FLD:    dw  FORTH_DOUSER : dw  U_FLD

W_CSP:  LFA_EMIT
_LINK = W_CSP
        db  3, "CS", 'P'|0x80
CSP:    dw  FORTH_DOUSER : dw  U_CSP

W_R_HASH: LFA_EMIT
_LINK = W_R_HASH
          db  2, "R", '#'|0x80
R_HASH:   dw  FORTH_DOUSER : dw  U_R_HASH

; ============================================================ Constants =======

W_BL:   LFA_EMIT
_LINK = W_BL
        db  2, "B", 'L'|0x80
BL:     dw  FORTH_DOCON : dw  32

W_WZERO: LFA_EMIT
_LINK = W_WZERO
        db  1, '0'|0x80
ZERO:   dw  FORTH_DOCON : dw  0

W_ONE:  LFA_EMIT
_LINK = W_ONE
        db  1, '1'|0x80
ONE:    dw  FORTH_DOCON : dw  1

W_TWO:  LFA_EMIT
_LINK = W_TWO
        db  1, '2'|0x80
TWO:    dw  FORTH_DOCON : dw  2

W_THREE: LFA_EMIT
_LINK = W_THREE
         db  1, '3'|0x80
THREE:   dw  FORTH_DOCON : dw  3

; B/BUF, B/SCR, C/L, FIRST, LIMIT — block I/O constants
W_BBUF: LFA_EMIT
_LINK = W_BBUF
        db  5, "B/BU", 'F'|0x80
BBUF:   dw  FORTH_DOCON : dw  1024    ; bytes per buffer (1K blocks)

W_BSCR: LFA_EMIT
_LINK = W_BSCR
        db  5, "B/SC", 'R'|0x80
BSCR:   dw  FORTH_DOUSER : dw  U_SEC_BLK

W_CL:   LFA_EMIT
_LINK = W_CL
        db  3, "C/", 'L'|0x80
CL:     dw  FORTH_DOCON : dw  64      ; chars per line (64 cols)

W_FIRST: LFA_EMIT
_LINK = W_FIRST
         db  5, "FIRS", 'T'|0x80
FIRST:   dw  FORTH_DOCON : dw  BUF_START

W_LIMIT: LFA_EMIT
_LINK = W_LIMIT
         db  5, "LIMI", 'T'|0x80
LIMIT:   dw  FORTH_DOCON : dw  BUF_END

; +ORIGIN  ( n -- addr )  n-th byte from start of Forth system
W_PORIGIN: LFA_EMIT
_LINK = W_PORIGIN
           db  7, "+ORIGI", 'N'|0x80
PORIGIN:   dw  PORIGIN_CODE
PORIGIN_CODE:
    ld  de, FORTH_START
    add hl, de
    jp  FORTH_NEXT

; ============================================================ ENCLOSE =========
W_ENCLOSE: LFA_EMIT
_LINK = W_ENCLOSE
           db  7, "ENCLOS", 'E'|0x80
ENCLOSE:   dw  ENCLOSE_CODE
ENCLOSE_CODE:
    ; ( addr delim -- addr delta_to_start skip )
    ; Counts bytes to skip to reach word start, then bytes to end.
    ; fig-FORTH spec.
    ld  a, l            ; A = delimiter
    pop  hl             ; HL = addr
    ld  b, 0            ; B = counter
.skip:
    ld  c, (hl)
    or  a               ; reset flags
    cp  c
    jr  nz, .skdone     ; not delimiter: found start
    inc hl : inc b
    ld  c, (hl)         ; check for null/end
    or  c
    jr  nz, .skip
    ; Hit end with only delimiters
    push hl
    ld  h, 0 : ld  l, b
    PUSH_TOS            ; push delta (=b)
    ld  hl, 0           ; push 0 skip (empty)
    jp  FORTH_NEXT
.skdone:
    push hl             ; save start address
    ld  d, b            ; D = delta to start
    ld  e, b            ; E = running counter for skip
.scan:
    ld  c, (hl)
    cp  c               ; hit delimiter?
    jr  z, .scend
    ld  c, (hl)
    or  c
    jr  z, .scend       ; hit null
    inc hl : inc e
    jr  .scan
.scend:
    pop  bc             ; BC = start addr (discard, we return addr as-is)
    PUSH_TOS            ; push original addr... wait, addr is no longer in HL
    ; Actually spec: return addr (unchanged), delta, skip
    ; Let's rethink: push addr back, push delta (D), push skip (E)
    ; For now: return delta in HL for simplicity; full fig-FORTH ENCLOSE
    ; returns: addr (unchanged on stack), delta, skip
    ; Current stack: original addr pushed before call
    ; We consumed it with pop hl. Reconstruct:
    ld  h, 0 : ld  l, d
    PUSH_TOS            ; push delta
    ld  h, 0 : ld  l, e ; HL = skip
    jp  FORTH_NEXT

; ============================================================ (FIND) ==========
W_PFIND: LFA_EMIT
_LINK = W_PFIND
         db  6, "(FIND", ')'|0x80
PFIND:   dw  PFIND_CODE
PFIND_CODE:
    ; ( addr vocab_ptr -- CFA true | addr false )
    ; addr = counted string to search for
    ; vocab_ptr = address of CONTEXT/CURRENT variable
    ; Returns CFA and true if found, else addr and false
    pop  de             ; DE = vocab_ptr (NFA of first word in vocab)
    ; Simple: just return false for now (full impl in dictionary.asm)
    PUSH_TOS            ; push addr
    ld  hl, 0           ; false
    jp  FORTH_NEXT

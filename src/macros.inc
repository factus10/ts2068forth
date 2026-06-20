; =============================================================================
; macros.inc — TS2068 fig-FORTH assembler macros
;
; KEY RULES for sjasmplus 1.22.0:
;   1. macro/endm keywords MUST be indented (not at column 0)
;   2. Variable assignments (_LINK = X) MUST be at column 0
;   3. Labels starting with digit are NOT valid (use ZBRANCH not 0BRANCH)
;   4. LD (DE),r is illegal Z80; must use LD A,r : LD (DE),A
; =============================================================================

    macro GOTO_NEXT
        jp  FORTH_NEXT
    endm

    macro PUSH_TOS
        push hl
    endm

    macro POP_TOS
        pop hl
    endm

    ; Push BC (IP) onto return stack. Destroys HL.
    macro RPUSH_BC
        ld  hl, (USER_START + U_RS_PTR)
        dec hl
        ld  (hl), b
        dec hl
        ld  (hl), c
        ld  (USER_START + U_RS_PTR), hl
    endm

    ; Pop return stack into BC (IP). Destroys HL.
    macro RPOP_BC
        ld  hl, (USER_START + U_RS_PTR)
        ld  c, (hl)
        inc hl
        ld  b, (hl)
        inc hl
        ld  (USER_START + U_RS_PTR), hl
    endm

    ; Push HL onto return stack. Destroys DE.
    macro RPUSH_HL
        ld  de, (USER_START + U_RS_PTR)
        dec de
        ld  a, h
        ld  (de), a
        dec de
        ld  a, l
        ld  (de), a
        ld  (USER_START + U_RS_PTR), de
    endm

    ; Pop return stack into HL. Destroys DE.
    macro RPOP_HL
        ld  de, (USER_START + U_RS_PTR)
        ld  a, (de)
        ld  l, a
        inc de
        ld  a, (de)
        ld  h, a
        inc de
        ld  (USER_START + U_RS_PTR), de
    endm

    ; Emit LFA dword pointing to previous word. Caller updates _LINK at column 0.
    macro LFA_EMIT
        dw  _LINK
    endm

F_IMM    EQU 0x40
F_SMUDGE EQU 0x20

; _LINK tracks the dictionary chain (initialized in primitives.asm at column 0)

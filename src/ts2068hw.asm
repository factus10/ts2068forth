; =============================================================================
; ts2068hw.asm — TS2068 hardware words
;
; Port I/O, display control, sound, timing.
; These are CODE words specific to the TS2068 platform.
; =============================================================================

; ============================================================ P@ =============
; P@  ( port -- byte )  Read byte from I/O port
W_PFETCH: LFA_EMIT
_LINK = W_PFETCH
          db  2, "P", '@'|0x80
PFETCH:   dw  PFETCH_CODE
PFETCH_CODE:
    ld  c, l            ; C = port (low byte)
    ld  b, h            ; B = high byte (for 16-bit port address)
    in  l, (c)          ; read port
    ld  h, 0
    jp  FORTH_NEXT

; ============================================================ P! =============
; P!  ( byte port -- )  Write byte to I/O port
W_PSTORE: LFA_EMIT
_LINK = W_PSTORE
          db  2, "P", '!'|0x80
PSTORE:   dw  PSTORE_CODE
PSTORE_CODE:
    ld  c, l            ; C = port low
    ld  b, h            ; B = port high
    pop  hl             ; HL = byte to write
    out (c), l          ; write low byte of value to port
    POP_TOS : jp  FORTH_NEXT

; ============================================================ BORDER =========
; BORDER  ( n -- )  Set border colour (0-7)
W_BORDER: LFA_EMIT
_LINK = W_BORDER
          db  6, "BORDE", 'R'|0x80
BORDER:   dw  BORDER_CODE
BORDER_CODE:
    ld  a, l
    and 7               ; mask to 3 bits
    out (PORT_FE), a    ; set border colour
    ; Also update system variable BORDCR
    rlca : rlca : rlca  ; shift to paper position (bits 3-5)
    ld  (SYSVAR_BORDCR), a
    POP_TOS : jp  FORTH_NEXT

; ============================================================ CLS ============
; CLS  ( -- )  Clear screen
W_CLS:  LFA_EMIT
_LINK = W_CLS
        db  3, "CL", 'S'|0x80
CLS:    dw  CLS_CODE
CLS_CODE:
    push hl             ; save TOS
    push bc             ; save IP
    call ROM_CLS        ; HOME ROM clear screen routine
    pop  bc
    pop  hl
    jp  FORTH_NEXT

; ============================================================ BEEP ===========
; BEEP  ( duration pitch -- )  Make a sound
; duration = time in 1/50ths of a second, pitch = semitone offset from middle C
W_BEEP: LFA_EMIT
_LINK = W_BEEP
        db  4, "BEE", 'P'|0x80
BEEP:   dw  BEEP_CODE
BEEP_CODE:
    ; ROM BEEP expects: HL = duration, DE = pitch (both as ROM format)
    ; Simplified: just pass raw values to ROM
    ld  de, hl          ; DE = pitch
    pop  hl             ; HL = duration
    push bc             ; save IP
    call ROM_BEEP
    pop  bc
    POP_TOS : jp  FORTH_NEXT

; ============================================================ MS =============
; MS  ( n -- )  Delay n milliseconds (approximate)
; Uses a busy-wait loop calibrated for 3.528 MHz Z80A
W_MS:   LFA_EMIT
_LINK = W_MS
        db  2, "M", 'S'|0x80
MS:     dw  MS_CODE
MS_CODE:
    ; Each ms ~3528 T-states. A simple loop of ~14 T-states/iter
    ; needs ~252 iterations per ms. Use 250 for close enough.
    ld  a, h : or  l
    jr  z, .ms_done
.ms_outer:
    ld  de, 250         ; iterations per millisecond
.ms_inner:
    dec de
    ld  a, d : or  e
    jr  nz, .ms_inner
    dec hl
    ld  a, h : or  l
    jr  nz, .ms_outer
.ms_done:
    POP_TOS : jp  FORTH_NEXT

; ============================================================ AT =============
; AT  ( row col -- )  Position cursor at row, col
; Uses Spectrum ROM control codes: chr(22) + row + col
W_AT:   LFA_EMIT
_LINK = W_AT
        db  2, "A", 'T'|0x80
AT:     dw  AT_CODE
AT_CODE:
    pop  de             ; DE = row
    ; HL = col
    push bc             ; save IP
    ld  a, 22           ; AT control code
    rst 0x10
    ld  a, e            ; row
    rst 0x10
    ld  a, l            ; col
    rst 0x10
    pop  bc
    POP_TOS : jp  FORTH_NEXT

; ============================================================ PLOT ===========
; PLOT  ( x y -- )  Plot pixel at x,y
W_PLOT: LFA_EMIT
_LINK = W_PLOT
        db  4, "PLO", 'T'|0x80
PLOT:   dw  PLOT_CODE
PLOT_CODE:
    ; ROM_PLOT ($22E5): B=y (0-175), C=x (0-255)
    ; Stack: ( x y -- )  TOS=y, NOS=x
    pop  de             ; DE = x
    ld  (PLOT_SAVE_IP), bc  ; save Forth IP (BC)
    ld  b, l            ; B = y
    ld  c, e            ; C = x
    call ROM_PLOT
    ld  bc, (PLOT_SAVE_IP)
    POP_TOS : jp  FORTH_NEXT


; ============================================================ DRAW ===========
; DRAW  ( dx dy -- )  Draw line relative from last PLOT position
W_DRAW: LFA_EMIT
_LINK = W_DRAW
        db  4, "DRA", 'W'|0x80
DRAW:   dw  DRAW_CODE
DRAW_CODE:
    ; ROM_DRAW at $2477 expects: C=dx, B=dy (signed 8-bit)
    pop  de             ; DE = dx
    ; HL = dy
    push bc             ; save IP
    ld  b, l            ; B = dy
    ld  c, e            ; C = dx
    call ROM_DRAW
    pop  bc
    POP_TOS : jp  FORTH_NEXT

; ============================================================ INK ============
; INK  ( n -- )  Set ink colour (0-7)
W_INK:  LFA_EMIT
_LINK = W_INK
        db  3, "IN", 'K'|0x80
INK:    dw  INK_CODE
INK_CODE:
    ; Set permanent ink colour in ATTR_P
    ld  a, (SYSVAR_ATTR_P)
    and 0xF8            ; clear ink bits (0-2)
    or  l               ; set new ink
    ld  (SYSVAR_ATTR_P), a
    ld  (SYSVAR_ATTR_T), a  ; also set temporary
    POP_TOS : jp  FORTH_NEXT

; ============================================================ PAPER ==========
; PAPER  ( n -- )  Set paper colour (0-7)
W_PAPER: LFA_EMIT
_LINK = W_PAPER
         db  5, "PAPE", 'R'|0x80
PAPER:   dw  PAPER_CODE
PAPER_CODE:
    ld  a, l
    and 7
    rlca : rlca : rlca  ; shift to paper position (bits 3-5)
    ld  e, a
    ld  a, (SYSVAR_ATTR_P)
    and 0xC7            ; clear paper bits (3-5)
    or  e               ; set new paper
    ld  (SYSVAR_ATTR_P), a
    ld  (SYSVAR_ATTR_T), a
    POP_TOS : jp  FORTH_NEXT

; ============================================================ BRIGHT =========
; BRIGHT  ( n -- )  Set bright attribute (0 or 1)
W_BRIGHT: LFA_EMIT
_LINK = W_BRIGHT
          db  6, "BRIGH", 'T'|0x80
BRIGHT:   dw  BRIGHT_CODE
BRIGHT_CODE:
    ld  a, (SYSVAR_ATTR_P)
    res 6, a             ; clear bright bit
    bit 0, l
    jr  z, .br_set
    set 6, a             ; set bright
.br_set:
    ld  (SYSVAR_ATTR_P), a
    ld  (SYSVAR_ATTR_T), a
    POP_TOS : jp  FORTH_NEXT

; ============================================================ FLASH ==========
; FLASH  ( n -- )  Set flash attribute (0 or 1)
W_FLASH: LFA_EMIT
_LINK = W_FLASH
         db  5, "FLAS", 'H'|0x80
FLASH:   dw  FLASH_CODE
FLASH_CODE:
    ld  a, (SYSVAR_ATTR_P)
    res 7, a             ; clear flash bit
    bit 0, l
    jr  z, .fl_set
    set 7, a             ; set flash
.fl_set:
    ld  (SYSVAR_ATTR_P), a
    ld  (SYSVAR_ATTR_T), a
    POP_TOS : jp  FORTH_NEXT

; ============================================================ Floating Point ==
; Uses the Spectrum ROM calculator via RST $28.
; FP values live on the ROM's calculator stack (at STKBOT/STKEND), separate
; from the Forth parameter stack. Forth words move values between the two.
;
; Key ROM routines:
;   $2D28 (STACK-A): push byte A as float onto calc stack
;   $2DA2 (FP-TO-BC): pop calc stack top -> BC (16-bit integer)
;   RST $28 + opcodes + $38: calculator sequence
;
; Calculator stack entries are 5 bytes each.

SYSVAR_STKBOT   EQU 0x5C63
SYSVAR_STKEND   EQU 0x5C65
ROM_STACK_A     EQU 0x2D28  ; push A as float
ROM_FP_TO_BC    EQU 0x2DA2  ; pop float -> BC (integer)
ROM_STACK_BC    EQU 0x2D2B  ; push BC as float (small integer form)
ROM_PRINT_FP    EQU 0x2DE3  ; print float at calc stack top

; INT>F  ( n -- ) ( F: -- r )  Push integer n onto FP stack
W_INTTOF: LFA_EMIT
_LINK = W_INTTOF
          db  5, "INT>", 'F'|0x80
INTTOF:   dw  INTTOF_CODE
INTTOF_CODE:
    ; HL = integer value. Push onto calc stack.
    ; Use ROM_STACK_BC which stacks BC as a small integer.
    push bc             ; save Forth IP
    ld  b, h : ld  c, l
    call ROM_STACK_BC
    pop  bc
    POP_TOS : jp  FORTH_NEXT

; F>INT  ( -- n ) ( F: r -- )  Pop FP stack top to Forth stack as integer
W_FTOINT: LFA_EMIT
_LINK = W_FTOINT
          db  5, "F>IN", 'T'|0x80
FTOINT:   dw  FTOINT_CODE
FTOINT_CODE:
    ; Pop FP stack top, convert to 16-bit integer, push onto Forth stack
    PUSH_TOS
    ld  (FTOINT_SAVE_IP), bc  ; save Forth IP
    call ROM_FP_TO_BC         ; result in BC
    ld  h, b : ld  l, c      ; HL = integer result (new TOS)
    ld  bc, (FTOINT_SAVE_IP)  ; restore Forth IP
    jp  FORTH_NEXT


; F+  ( ) ( F: r1 r2 -- r1+r2 )  Add top two FP values
W_FPLUS: LFA_EMIT
_LINK = W_FPLUS
         db  2, "F", '+'|0x80
FPLUS:   dw  FPLUS_CODE
FPLUS_CODE:
    push bc
    rst 0x28
    db  0x0F            ; addition
    db  0x38            ; end-calc
    pop  bc
    jp  FORTH_NEXT

; F-  ( ) ( F: r1 r2 -- r1-r2 )
W_FMINUS: LFA_EMIT
_LINK = W_FMINUS
          db  2, "F", '-'|0x80
FMINUS:   dw  FMINUS_CODE
FMINUS_CODE:
    push bc
    rst 0x28
    db  0x03            ; subtract
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; F*  ( ) ( F: r1 r2 -- r1*r2 )
W_FSTAR: LFA_EMIT
_LINK = W_FSTAR
         db  2, "F", '*'|0x80
FSTAR:   dw  FSTAR_CODE
FSTAR_CODE:
    push bc
    rst 0x28
    db  0x04            ; multiply
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; F/  ( ) ( F: r1 r2 -- r1/r2 )
W_FSLASH: LFA_EMIT
_LINK = W_FSLASH
          db  2, "F", '/'|0x80
FSLASH:   dw  FSLASH_CODE
FSLASH_CODE:
    push bc
    rst 0x28
    db  0x05            ; division
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FNEGATE  ( ) ( F: r -- -r )
W_FNEGATE: LFA_EMIT
_LINK = W_FNEGATE
           db  7, "FNEGAT", 'E'|0x80
FNEGATE:   dw  FNEGATE_CODE
FNEGATE_CODE:
    push bc
    rst 0x28
    db  0x1B            ; negate
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FSQRT  ( ) ( F: r -- sqrt(r) )
W_FSQRT: LFA_EMIT
_LINK = W_FSQRT
          db  5, "FSQR", 'T'|0x80
FSQRT:    dw  FSQRT_CODE
FSQRT_CODE:
    push bc
    rst 0x28
    db  0x28            ; sqr
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FSIN  ( ) ( F: r -- sin(r) )
W_FSIN: LFA_EMIT
_LINK = W_FSIN
        db  4, "FSI", 'N'|0x80
FSIN:   dw  FSIN_CODE
FSIN_CODE:
    push bc
    rst 0x28
    db  0x1F            ; sin
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FCOS  ( ) ( F: r -- cos(r) )
W_FCOS: LFA_EMIT
_LINK = W_FCOS
        db  4, "FCO", 'S'|0x80
FCOS:   dw  FCOS_CODE
FCOS_CODE:
    push bc
    rst 0x28
    db  0x20            ; cos
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FTAN  ( ) ( F: r -- tan(r) )
W_FTAN: LFA_EMIT
_LINK = W_FTAN
        db  4, "FTA", 'N'|0x80
FTAN:   dw  FTAN_CODE
FTAN_CODE:
    push bc
    rst 0x28
    db  0x21            ; tan
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FLN  ( ) ( F: r -- ln(r) )
W_FLN:  LFA_EMIT
_LINK = W_FLN
        db  3, "FL", 'N'|0x80
FLN:    dw  FLN_CODE
FLN_CODE:
    push bc
    rst 0x28
    db  0x25            ; ln
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FEXP  ( ) ( F: r -- exp(r) )
W_FEXP: LFA_EMIT
_LINK = W_FEXP
        db  4, "FEX", 'P'|0x80
FEXP:   dw  FEXP_CODE
FEXP_CODE:
    push bc
    rst 0x28
    db  0x26            ; exp
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FABS  ( ) ( F: r -- |r| )
W_FABS: LFA_EMIT
_LINK = W_FABS
        db  4, "FAB", 'S'|0x80
FABS:   dw  FABS_CODE
FABS_CODE:
    push bc
    rst 0x28
    db  0x2A            ; abs
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FDUP  ( ) ( F: r -- r r )
W_FDUP: LFA_EMIT
_LINK = W_FDUP
        db  4, "FDU", 'P'|0x80
FDUP:   dw  FDUP_CODE
FDUP_CODE:
    push bc
    rst 0x28
    db  0x31            ; duplicate
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FDROP  ( ) ( F: r -- )
W_FDROP: LFA_EMIT
_LINK = W_FDROP
         db  5, "FDRO", 'P'|0x80
FDROP:   dw  FDROP_CODE
FDROP_CODE:
    push bc
    rst 0x28
    db  0x02            ; delete
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; FSWAP  ( ) ( F: r1 r2 -- r2 r1 )
W_FSWAP: LFA_EMIT
_LINK = W_FSWAP
         db  5, "FSWA", 'P'|0x80
FSWAP:   dw  FSWAP_CODE
FSWAP_CODE:
    push bc
    rst 0x28
    db  0x01            ; exchange
    db  0x38
    pop  bc
    jp  FORTH_NEXT

; F.  ( ) ( F: r -- )  Print top of FP stack
W_FDOT: LFA_EMIT
_LINK = W_FDOT
        db  2, "F", '.'|0x80
FDOT:   dw  FDOT_CODE
FDOT_CODE:
    push bc
    ; ROM_PRINT_FP prints the value at (DE) and removes it from calc stack
    ; We need DE to point to the last value on the calc stack.
    ; The top value is at STKEND-5.
    ld  de, (SYSVAR_STKEND)
    ld  hl, 0xFFFB      ; -5
    add hl, de
    ex  de, hl          ; DE = STKEND - 5 = top FP value
    call ROM_PRINT_FP
    ; Remove the value from calc stack (STKEND -= 5)
    ld  hl, (SYSVAR_STKEND)
    ld  de, 0xFFFB      ; -5
    add hl, de
    ld  (SYSVAR_STKEND), hl
    ld  a, 32 : rst 0x10  ; trailing space
    pop  bc
    jp  FORTH_NEXT

; ============================================================ Tape I/O =======
; Uses the TS2068 function dispatcher for tape services.
; Dispatcher convention: push PRM_OUT, PRM_IN, SVC_CODE, then CALL dispatcher.

; Helper: call dispatcher with service code in A, no stack parameters
_CALL_DISPATCHER:
    push hl : push bc     ; save Forth regs
    ld  de, 0
    push de               ; PRM_OUT = 0
    push de               ; PRM_IN = 0
    ld  e, a : ld  d, 0
    push de               ; SVC_CODE
    ld  a, (0x5CC2)       ; VIDMOD
    or  a
    jr  nz, .cd_ext
    call 0x6200           ; normal dispatcher
    jr  .cd_done
.cd_ext:
    call 0xF9C0           ; extended video dispatcher
.cd_done:
    pop  bc : pop  hl     ; restore Forth regs
    ret

; =============================================================================
; Shared EXROM tape I/O (cartridge-safe)
;
; The cassette primitives live in the TS2068 EXROM at chunk 0 ($0068 = W_TAPE
; save, $00FC = R_TAPE load). A DOCK cartridge maps the EXROM out, so we page it
; back into chunk 0 on demand. Enabling the EXROM (DECR/$FF bit 7) can page out
; the cartridge ROM, so the bank-switch + EXROM call MUST run from RAM — exactly
; like Zebra OS-64's BANK_SWITCH_CODE ($0DBC). COLD copies the position-independent
; stub below into TAPE_STUB ($FB00, chunk-7 RAM that the EXROM never touches).
; _MC_TAPE_SAVE/_LOAD patch the stub's CALL operand (the stub is in RAM, writable)
; and jump to it; the stub enables the EXROM, calls the primitive, restores, rets.
;
;   _MC_TAPE_SAVE: IX=addr, DE=len, A=block type ($00 header / $FF data)
;   _MC_TAPE_LOAD: IX=dest, DE=len, A=expected type
; On return: CF set = OK, CF clear = BREAK/error.
; IX (buffer) MUST be safe RAM ($C000+ or the $F000 buffers) — never chunk 0/1.
; PORT_BANK=$F4 (HSR), PORT_TMPR=$FF (DECR; bit 7 = EXROM enable).
; =============================================================================
_MC_TAPE_SAVE:
    ld   hl, 0x0068             ; W_TAPE; patch the RAM stub's CALL operand
    ld   (TAPE_STUB + TS_OP), hl
    jp   TAPE_STUB              ; run from RAM; stub RETs to our caller
_MC_TAPE_LOAD:
    ld   hl, 0x00FC             ; R_TAPE
    ld   (TAPE_STUB + TS_OP), hl
    jp   TAPE_STUB

; Position-independent template copied to TAPE_STUB at COLD. Runs from RAM.
; (Only the absolute CALL operand is patched per-call; the rest is relocatable —
;  no jr/jp, so it executes correctly at $FB00.)
_TAPE_STUB_ROM:
    di
    push af                     ; save type byte (the OUTs clobber A)
    in   a, (PORT_TMPR) : set 7, a : out (PORT_TMPR), a   ; enable EXROM
    ld   a, 0x31 : out (PORT_BANK), a                      ; HSR: chunk0<-EXROM
    pop  af                     ; A = type
    scf                         ; CF set (LOAD for R_TAPE; harmless for W_TAPE)
_TAPE_STUB_CALL:
    call 0x0000                 ; operand patched to $0068 / $00FC
    push af                     ; preserve tape result carry
    in   a, (PORT_TMPR) : res 7, a : out (PORT_TMPR), a    ; disable EXROM
    ld   a, 0x30 : out (PORT_BANK), a                       ; restore HSR ($30)
    pop  af                     ; CF = tape result (set=OK)
    ei
    ret
_TAPE_STUB_END:
TS_LEN  EQU _TAPE_STUB_END - _TAPE_STUB_ROM
TS_OP   EQU _TAPE_STUB_CALL + 1 - _TAPE_STUB_ROM   ; offset of CALL operand

; TSAVE  ( addr len -- )  Save a memory block to tape with filename
; Usage: TSAVE addr len name
; Parses filename from input. Saves header + data block.
W_TSAVE: LFA_EMIT
_LINK = W_TSAVE
         db  5, "TSAV", 'E'|0x80
TSAVE:   dw  TSAVE_CODE
TSAVE_CODE:
    ; TOS=len(HL), NOS=addr
    ld  (TAPE_DATALEN), hl  ; save length
    pop  hl
    ld  (TAPE_DATAADDR), hl ; save address
    ; Parse filename from input (required)
    ld  hl, 32
    call _MC_WORD
    ; Build tape header
    call _TAPE_BUILD_HDR
    ; Print prompt
    ld  a, 13 : rst 0x10
    ld  hl, _STR_SAVING
    call _PRINT_STR
    ; Save header block, then data block (bank-switch inside _MC_TAPE_SAVE)
    ld  ix, TAPE_HDR
    ld  de, 17
    xor a                   ; $00 = header block
    call _MC_TAPE_SAVE
    ld  ix, (TAPE_DATAADDR)
    ld  de, (TAPE_DATALEN)
    ld  a, 0xFF             ; $FF = data block
    call _MC_TAPE_SAVE
    POP_TOS : jp  FORTH_NEXT

; TLOAD  ( addr len -- )  Load a memory block from tape
; Usage: TLOAD addr len name   (or TLOAD addr len for first file)
; Parses optional filename. Loads header then data block.
W_TLOAD: LFA_EMIT
_LINK = W_TLOAD
         db  5, "TLOA", 'D'|0x80
TLOAD:   dw  TLOAD_CODE
TLOAD_CODE:
    ; TOS=len(HL), NOS=addr
    ld  (TAPE_DATALEN), hl
    pop  hl
    ld  (TAPE_DATAADDR), hl
    ; Parse optional filename
    ld  hl, 32
    call _MC_WORD
    ld  a, (hl)
    and 0x1F
    ld  (TAPE_NAME_LEN), a ; 0 = accept any file
    ; Print prompt
    ld  a, 13 : rst 0x10
    ld  hl, _STR_LOADING
    call _PRINT_STR
    ; Load header block, then data block (bank-switch inside _MC_TAPE_LOAD)
    ld  ix, TAPE_HDR
    ld  de, 17
    xor a                   ; $00 = header block
    call _MC_TAPE_LOAD
    ld  ix, (TAPE_DATAADDR)
    ld  de, (TAPE_DATALEN)
    ld  a, 0xFF             ; $FF = data block
    call _MC_TAPE_LOAD
    POP_TOS : jp  FORTH_NEXT

_STR_SAVING: db "SAVE tape...", 13, 0
_STR_LOADING: db "LOAD tape...", 13, 0

; Helper: build 17-byte tape header from parsed WORD at HERE
; Uses TAPE_DATALEN and TAPE_DATAADDR for length/start fields.
_TAPE_BUILD_HDR:
    ld  de, TAPE_HDR
    ld  a, 3                ; type = CODE
    ld  (de), a : inc de
    ; Copy filename from HERE (up to 10 chars, space-padded)
    ld  hl, (USER_START + U_DP)  ; HERE
    ld  a, (hl)
    and 0x1F
    ld  c, a                ; C = name length
    inc hl                  ; past count byte
    ld  b, 10               ; 10 chars for filename field
.tbh_name:
    ld  a, c
    or  a
    jr  z, .tbh_pad
    ld  a, (hl)
    and 0x7F                ; strip high bit
    ld  (de), a
    inc hl : inc de
    dec c : dec b
    jr  nz, .tbh_name
    jr  .tbh_done
.tbh_pad:
    ld  a, 32
    ld  (de), a : inc de
    dec b
    jr  nz, .tbh_pad
.tbh_done:
    ; Data length
    ld  hl, (TAPE_DATALEN)
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ; Start address
    ld  hl, (TAPE_DATAADDR)
    ld  a, l : ld  (de), a : inc de
    ld  a, h : ld  (de), a : inc de
    ; Parameter 2
    xor a : ld  (de), a : inc de : ld  (de), a
    ret

; SAVE-BUFFERS  ( -- )  Save all buffers to tape with filename
; Usage: SAVE-BUFFERS myfile
; Parses filename from input. Saves a header block then data block.
W_SAVEBUF: LFA_EMIT
_LINK = W_SAVEBUF
           db  12, "SAVE-BUFFER", 'S'|0x80
SAVEBUF:   dw  SAVEBUF_CODE
SAVEBUF_CODE:
    PUSH_TOS
    ; Parse filename from input (required)
    ld  hl, 32
    call _MC_WORD
    ; Set up data addr/len for buffer area
    ld  hl, BUF_END - BUF_START + 1
    ld  (TAPE_DATALEN), hl
    ld  hl, BUF_START
    ld  (TAPE_DATAADDR), hl
    ; Build header using shared helper
    call _TAPE_BUILD_HDR
    ; Print prompt
    ld  a, 13 : rst 0x10
    ld  hl, _STR_SAVING
    call _PRINT_STR
    ; Save header block, then buffer data block
    ld  ix, TAPE_HDR
    ld  de, 17
    xor a                   ; $00 = header block
    call _MC_TAPE_SAVE
    ld  ix, BUF_START
    ld  de, BUF_END - BUF_START + 1
    ld  a, 0xFF             ; $FF = data block
    call _MC_TAPE_SAVE
    POP_TOS : jp  FORTH_NEXT

; LOAD-BUFFERS  ( -- )  Load buffers from tape
; Usage: LOAD-BUFFERS name   (or just LOAD-BUFFERS for first file found)
; Parses optional filename. Loads header, checks match, then loads data.
W_LOADBUF: LFA_EMIT
_LINK = W_LOADBUF
           db  12, "LOAD-BUFFER", 'S'|0x80
LOADBUF:   dw  LOADBUF_CODE
LOADBUF_CODE:
    PUSH_TOS
    ; Parse optional filename
    ld  hl, 32
    call _MC_WORD           ; HL = HERE (counted string)
    ld  a, (hl)
    and 0x1F
    ld  (TAPE_NAME_LEN), a ; 0 = accept any file
    ; Print prompt
    ld  a, 13 : rst 0x10
    ld  hl, _STR_LOADING
    call _PRINT_STR
    ; Load header block (accept any name for now), then buffer data block
    ld  ix, TAPE_HDR
    ld  de, 17
    xor a                   ; $00 = header block
    call _MC_TAPE_LOAD
    ld  ix, BUF_START
    ld  de, BUF_END - BUF_START + 1
    ld  a, 0xFF             ; $FF = data block
    call _MC_TAPE_LOAD
    POP_TOS : jp  FORTH_NEXT

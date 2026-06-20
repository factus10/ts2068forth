; =============================================================================
; main.asm — TS2068 fig-FORTH
;
; Builds a 16K ROM image for a DOCK-bank LROS cartridge ($8000-$BFFF).
; The TS2068 EXROM boot detects the LROS header (built by tools/mkdck.py) and
; autostarts CART_ENTRY at $8000 — no BASIC, no RANDOMIZE USR.
;
; Output: raw 16K binary -> tools/mkdck.py wraps it as a .dck cartridge.
; (The same binary can also be loaded into RAM at $8000 for quick ZRCP tests.)
; =============================================================================

    DEVICE  NOSLOT64K

; Include hardware constants and macros
    INCLUDE "ts2068.inc"
    INCLUDE "macros.inc"

; =============================================================================
; Code starts at $8000 (LROS header points here; OS jumps here after banking)
; =============================================================================
    ORG     FORTH_START         ; $8000 (DOCK chunk 4)

CART_ENTRY:
    DI
    LD      SP, PS_TOP
    XOR     A
    LD      I, A
    IM      1
    ; Initialize keyboard system variables
    XOR     A
    LD      (0x5C41), A         ; MODE = 0
    LD      A, 35
    LD      (0x5C09), A         ; REPDEL
    LD      A, 5
    LD      (0x5C0A), A         ; REPPER
    LD      A, 0x28
    LD      (0x5C3B), A         ; FLAGS
    EI
    JP      FORTH_COLD

; =============================================================================
; Include source modules
; =============================================================================
    INCLUDE "engine.asm"
    INCLUDE "primitives.asm"
    INCLUDE "ts2068hw.asm"
    INCLUDE "dictionary.asm"
    INCLUDE "userwords.asm"

; =============================================================================
; Size check
; =============================================================================
FORTH_END:
FORTH_ACTUAL_SIZE EQU $ - FORTH_START
    IF FORTH_ACTUAL_SIZE > FORTH_MAX_SIZE
        DISPLAY "*** ERROR: Code overflow by ", /D, FORTH_ACTUAL_SIZE - FORTH_MAX_SIZE, " bytes"
        ERROR   "Code exceeds 16K"
    ELSE
        DISPLAY "Code size: ", /D, FORTH_ACTUAL_SIZE, " / ", /D, FORTH_MAX_SIZE, " bytes"
        DISPLAY "Free: ", /D, FORTH_MAX_SIZE - FORTH_ACTUAL_SIZE, " bytes"
    ENDIF

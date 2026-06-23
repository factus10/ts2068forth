; =============================================================================
; ts2068.inc — TS2068 hardware constants
; =============================================================================

; --- Port addresses ----------------------------------------------------------
PORT_BANK       EQU 0xF4    ; Memory bank switching register
PORT_AY_REG     EQU 0xF5    ; AY-3-8912 register select
PORT_AY_DATA    EQU 0xF6    ; AY-3-8912 data
PORT_TMPR       EQU 0xFF    ; Timex memory page (write)
PORT_FE         EQU 0xFE    ; Border/ear/mic (Spectrum compatible)
PORT_1F         EQU 0x1F    ; Kempston joystick
PORT_7F         EQU 0x7F    ; AY-3-8912 (alternate address)

; --- Bank register values (PORT_BANK) ----------------------------------------
; bits [2:0] = HOME bank:  0=HOME ROM, 1=DOCK, 2=EXROM, 4=RAM4, 5=RAM5, 6=RAM6, 7=RAM7
; bits [5:3] = middle bank: same encoding for 0x8000-0xBFFF
; Normal running config: HOME ROM + RAM at 0x8000 + DOCK cartridge at 0xC000
BANK_HOME_ROM   EQU 0x00    ; HOME bank = HOME ROM
BANK_DOCK       EQU 0x01    ; HOME bank = DOCK (for DOCK at 0x0000 if needed)
BANK_EXROM      EQU 0x02    ; HOME bank = EXROM
BANK_RAM4       EQU 0x04    ; HOME bank = RAM4
BANK_RAM5       EQU 0x05    ; HOME bank = RAM5 (screen RAM)
BANK_RAM6       EQU 0x06
BANK_RAM7       EQU 0x07

; Our running bank config: HOME ROM | RAM5 at 0x8000 | DOCK at 0xC000
; DOCK is always-on for our cartridge, no switching needed for ROM access
; EXROM switching: temporarily swap DOCK for EXROM to call EXROM routines
BANK_NORMAL     EQU 0x00    ; HOME=HOME_ROM, middle=RAM, DOCK at 0xC000
BANK_EXROM_ON   EQU 0x02    ; Switch EXROM into 0xC000 (replaces our ROM!)
; NOTE: EXROM_ON will replace our own ROM, so we must be running from RAM
;       when we do EXROM calls. This requires a trampoline in RAM.

; --- EXROM routine addresses (when EXROM mapped to 0xC000) -------------------
; These are the Timex EXROM entry points
EXROM_PRINT_AT  EQU 0xC02E  ; Print at row, col
EXROM_CLS       EQU 0xC000  ; Clear screen (check actual TS2068 EXROM map)

; --- Spectrum ROM addresses (HOME ROM at 0x0000) ------------------------------
ROM_CLS         EQU 0x08A6  ; Clear screen
ROM_PRINT_A     EQU 0x10    ; RST 0x10: print char in A
ROM_BREAK       EQU 0x1820  ; Check BREAK key
ROM_BEEP        EQU 0x03B5  ; BEEP (HL=duration, DE=pitch)
ROM_BORDER      EQU 0x2007  ; Set border colour
ROM_PLOT        EQU 0x22E5  ; PLOT pixel
ROM_DRAW        EQU 0x2477  ; DRAW line
ROM_OPEN_CHAN   EQU 0x1601  ; Open channel
ROM_PRINT_CHAN  EQU 0x1230  ; Output A to current channel
ROM_KEY_SCAN    EQU 0x028E  ; Keyboard scan
ROM_NEXT_CHAR   EQU 0x0018  ; RST 0x18: get char from current stream

; --- Spectrum system variables (in RAM) --------------------------------------
SYSVAR_BASE     EQU 0x5C00
SYSVAR_FLAGS    EQU 0x5C3B  ; FLAGS
SYSVAR_ATTR_P   EQU 0x5C8D  ; ATTR_P (permanent colour attributes)
SYSVAR_ATTR_T   EQU 0x5C8F  ; ATTR_T (temporary colour attributes)
SYSVAR_BORDCR   EQU 0x5C48  ; BORDCR (border colour)
SYSVAR_LASTK    EQU 0x5C08  ; LAST_K (last keypress)
SYSVAR_DF_CC    EQU 0x5C88  ; DF_CC (cursor address in display file)
SYSVAR_TVDATA   EQU 0x5C51  ; TVDATA
SYSVAR_STRMS    EQU 0x5C10  ; STRMS (stream table, 3 bytes each x 16)
SYSVAR_PROG     EQU 0x5C53  ; PROG (start of BASIC program)
SYSVAR_VARS     EQU 0x5C4B  ; VARS (start of variables area)
SYSVAR_FRAMES   EQU 0x5C78  ; FRAMES (frame counter, 3 bytes)

; --- Forth memory map (LROS cartridge) ---------------------------------------
; The Forth ROM image lives in the DOCK cartridge at $8000-$BFFF (chunks 4-5).
; The TS2068 EXROM boot reads the LROS header at DOCK $0001-$0004 and, for
; chunk-spec $EF (= HSR $30), jumps straight to our $8000 entry with HOME ROM
; mapped in chunks 0-3 (print/keyboard/FP) and RAM in chunks 6-7. Because the
; image runs from ROM, ALL mutable state must live in RAM: the dictionary
; ($C000+), the stacks/TIB/PAD/USER ($F000+), and the scratch sysvar page
; ($FA00, see above). Nothing writable may be inline in the code segment.
FORTH_START     EQU 0x8000  ; Cartridge ROM entry (DOCK chunk 4)
FORTH_MAX_SIZE  EQU 0x4000  ; 16K max for code ($8000-$BFFF, chunks 4-5)

; The dictionary is RAM that grows up to $FFFF. Where it STARTS depends on the build:
;
;   Cartridge (default): $8000-$BFFF is DOCK ROM, so the dictionary can only use
;     the RAM of chunks 6-7 -> starts at $C000 (16K).
;
;   RAM/TAP build (-DRAM_BUILD): the engine is loaded into RAM, so there's no ROM
;     shadowing $8000-$BFFF. The user dictionary starts just above the engine image
;     (engine ends ~$A4xx; $A800 leaves headroom) and runs to $FFFF -> ~22K. This
;     reclaims the ~6.7K gap the cartridge wastes between the engine and $C000,
;     plus the 16K of HOME RAM the cartridge ROM normally hides.
    IFDEF RAM_BUILD
DICT_RAM_START  EQU 0xA800  ; RAM build: dictionary right above the RAM-loaded engine
    ELSE
DICT_RAM_START  EQU 0xC000  ; cartridge: dictionary in chunks 6-7 (ROM at $8000-$BFFF)
    ENDIF
DICT_RAM_END    EQU 0xFFFF  ; dictionary top (both builds)

; System areas relocated to free chunk-3 RAM ($7000-$7BFF, ~2.6K used of 4K)
BUF_START       EQU 0x7000  ; Block buffers (1K, one block)
BUF_END         EQU 0x73FF

PS_TOP          EQU 0x7600  ; Parameter stack grows DOWN from here
PS_BOTTOM       EQU 0x7400  ; Minimum PS pointer (overflow check)

RS_TOP          EQU 0x7800  ; Return stack grows DOWN from here
RS_BOTTOM       EQU 0x7600  ; Minimum RS pointer (overflow check)

TIB_START       EQU 0x7800  ; Terminal Input Buffer (256 bytes)
TIB_END         EQU 0x78FF

PAD_START       EQU 0x7900  ; PAD scratch area (192 bytes)
PAD_END         EQU 0x79BF

USER_START      EQU 0x79C0  ; USER variables (64 bytes)
USER_END        EQU 0x79FF

; Scratch variables are declared inline (dw/db) in the source files.
; Since Forth is loaded into RAM (not ROM), they are writable in place.

; --- USER variable offsets (from USER_START) ----------------------------------
; These mirror the fig-FORTH user variable layout
U_SP0           EQU 0       ; S0: initial parameter stack pointer
U_R0            EQU 2       ; R0: initial return stack pointer
U_TIB           EQU 4       ; TIB: address of terminal input buffer
U_WIDTH         EQU 6       ; WIDTH: name field width (31)
U_WARNING       EQU 8       ; WARNING: warning flag
U_FENCE         EQU 10      ; FENCE: FORGET protection address
U_DP            EQU 12      ; DP: dictionary pointer (HERE)
U_VOC_LINK      EQU 14      ; VOC-LINK: vocabulary link
U_BLK           EQU 16      ; BLK: current block being interpreted
U_IN            EQU 18      ; IN: input pointer within TIB
U_OUT           EQU 20      ; OUT: output position
U_SCR           EQU 22      ; SCR: current screen being listed
U_OFFSET        EQU 24      ; OFFSET: disk block offset
U_CONTEXT       EQU 26      ; CONTEXT: search vocabulary pointer
U_CURRENT       EQU 28      ; CURRENT: compile vocabulary pointer
U_STATE         EQU 30      ; STATE: 0=interpret, 1=compile
U_BASE          EQU 32      ; BASE: number base (default 10)
U_DPL           EQU 34      ; DPL: decimal point location
U_FLD           EQU 36      ; FLD: field width
U_CSP           EQU 38      ; CSP: stack pointer at compile start
U_R_HASH        EQU 40      ; R#: line number for EDITOR
U_HLD           EQU 42      ; HLD: hold area pointer
U_RS_PTR        EQU 44      ; Return stack pointer (our addition)
U_DRIVE         EQU 46      ; current drive number
U_DENSITY       EQU 48      ; disk density flag
U_SEC_BLK       EQU 50      ; sectors per block
U_N_BUFF        EQU 52      ; number of buffers
U_USE           EQU 54      ; USE: next buffer to use
U_PREV          EQU 56      ; PREV: most recently used buffer
U_DISK_ERR      EQU 58      ; DISK-ERROR: disk error handler vector
U_CAPS          EQU 60      ; CAPS lock flag (TS2068 specific)
U_PRINTER       EQU 62      ; printer output flag (TS2068 specific)

; --- Scratch sysvar page (RAM) -----------------------------------------------
; Mutable interpreter scratch cells. Previously these lived INLINE in the code
; segment (LABEL: dw 0) and were written via `ld (LABEL),...`. That works when
; the image runs in RAM, but FAILS in a ROM cartridge — the writes go to ROM and
; are silently dropped. Relocating them here (a fixed RAM page) makes the code
; image ROM-safe. Each cell keeps its original label so call sites are unchanged.
; Defined relative to the previous cell so the layout is self-sizing.
SCRATCH_START       EQU 0x7A00
FORTH_IP            EQU SCRATCH_START          ; 2  inner-interpreter IP
INTERP_TOKEN        EQU FORTH_IP + 2           ; 2
INTERP_THREAD       EQU INTERP_TOKEN + 2       ; 4  [CFA, INTERP_RESUME] trampoline
INTERP_NEG          EQU INTERP_THREAD + 4      ; 1
MF_HERE             EQU INTERP_NEG + 1         ; 2
PN_ADDR             EQU MF_HERE + 2            ; 2
PN_DLO              EQU PN_ADDR + 2            ; 2
PN_DHI              EQU PN_DLO + 2             ; 2
PN_DIGIT            EQU PN_DHI + 2             ; 1
PN_PRODHI           EQU PN_DIGIT + 1           ; 2
NUM_NEG             EQU PN_PRODHI + 2          ; 1
HASH_DLO            EQU NUM_NEG + 1            ; 2
HASH_QHI            EQU HASH_DLO + 2           ; 2
WORD_DELIM          EQU HASH_QHI + 2           ; 1
WORD_SRC            EQU WORD_DELIM + 1         ; 2
DOT_SIGN            EQU WORD_SRC + 2           ; 1
INTERPRET_SAVE_IP   EQU DOT_SIGN + 1           ; 2
BUF_USE_IDX         EQU INTERPRET_SAVE_IP + 2  ; 1
LOAD_SAVE_BLK       EQU BUF_USE_IDX + 1        ; 2
LOAD_SAVE_IN        EQU LOAD_SAVE_BLK + 2      ; 2
LOAD_TOKEN          EQU LOAD_SAVE_IN + 2       ; 2
LOAD_NEG            EQU LOAD_TOKEN + 2         ; 1
EXECUTE_TEMP        EQU LOAD_NEG + 1           ; 2
PLOT_SAVE_IP        EQU EXECUTE_TEMP + 2       ; 2
FTOINT_SAVE_IP      EQU PLOT_SAVE_IP + 2       ; 2
TAPE_NAME_LEN       EQU FTOINT_SAVE_IP + 2     ; 1
TAPE_DATALEN        EQU TAPE_NAME_LEN + 1      ; 2
TAPE_DATAADDR       EQU TAPE_DATALEN + 2       ; 2
TAPE_HDR            EQU TAPE_DATAADDR + 2      ; 17 tape header buffer (built at runtime)
SCRATCH_END         EQU TAPE_HDR + 17          ; (= SCRATCH_START + 67)

; RAM-resident EXROM bank-switch stub (copied from ROM at COLD). The bank switch
; that pages the EXROM into chunk 0 must execute from RAM, because enabling the
; EXROM can page out the cartridge ROM (chunks 4-5) the code would otherwise run
; from. $7B00 is chunk-3 RAM, which the EXROM never touches, so it stays mapped.
TAPE_STUB           EQU 0x7B00

; Convenience macros for USER variable access

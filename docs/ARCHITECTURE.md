# TS2068 fig-FORTH: Architecture Document

## Project Goal

A new fig-FORTH implementation for the Timex/Sinclair 2068, delivered as an 8K DOCK
cartridge binary. Combines the best of two existing implementations:

- **Burton (Robert J. Burton, ~198x)**: Clean Z80 code, TS2068-native hardware words,
  public domain. Base engine.
- **Hawg Wild Software (1985)**: Screen editor, graphics, floating point via ROM,
  tape I/O, additional utilities.

---

## Assembler

**sjasmplus v1.22.0** — industry standard for ZX Spectrum/TS2068 development.

Key features used:
- `MACRO` / `ENDM` for NEXT, DOCOL, header macros
- `MODULE` for namespace separation
- `DEVICE ZXSPECTRUM48` for memory model (we override with custom ORG)
- `SAVESNA` / `SAVEBIN` for output
- Conditional assembly for debug vs. release builds

---

## Memory Map

```
0x0000-0x3FFF  HOME ROM (Spectrum-compatible, 16K) — bank-switchable
0x4000-0x7FFF  RAM bank 5 (screen + system)
0x8000-0x9FFF  RAM: Forth dictionary RAM (8K, user-extensible)
0xA000-0xAFFF  RAM: Block buffers (16 × 256-byte blocks = 4K)
0xB000-0xB7FF  RAM: Parameter stack space (2K, grows DOWN from 0xB800)
0xB800-0xBDFF  RAM: Return stack space (1.5K, grows DOWN from 0xBE00)
0xBE00-0xBEFF  RAM: TIB (Terminal Input Buffer, 256 bytes)
0xBF00-0xBFBF  RAM: PAD (scratch area, 192 bytes)
0xBFC0-0xBFFF  RAM: USER area (64 bytes of user variables)
0xC000-0xDFFF  DOCK ROM: Forth engine + all CODE primitives (8K)
```

### Stack conventions

- **Parameter stack (PS)**: SP register, grows down from 0xB800
- **Return stack (RS)**: Managed via variable at (RS_TOP), grows down from 0xBE00
  - Stored in memory-variable, not a Z80 register, matching Burton's approach
- **TOS (Top of Stack)**: In HL register (matching Burton)

### TS2068 EXROM bank-switching

The TS2068 EXROM (8K, Timex extended routines) appears at 0xC000 when switched in.
Since our Forth ROM occupies 0xC000, EXROM access requires temporarily swapping banks:

```
EXROM_CALL MACRO routine_addr
    ; Save our ROM, switch in EXROM, call, restore
    LD A, EXROM_BANK
    OUT (PORT_BANK), A
    CALL routine_addr
    LD A, DOCK_BANK
    OUT (PORT_BANK), A
ENDM
```

Used for: floating point routines, some display routines.

---

## Inner Interpreter

**Model**: Indirect Threaded Code (ITC), matching both reference implementations.

### Register allocation

| Register | Role |
|----------|------|
| BC | Instruction Pointer (IP) |
| HL | Top of Parameter Stack (TOS) |
| SP | Parameter Stack pointer |
| (0xBFF0) | Return Stack pointer (16-bit, in USER area) |
| DE | scratch / working register |
| IX | scratch |
| IY | **must not be destroyed** (Spectrum interrupt handler uses IY) |

### NEXT macro

```asm
MACRO NEXT
    LD A, (BC)      ; fetch low byte of CFA address from thread
    INC BC
    LD H, A         ; H = low byte (single-byte high-page trick NOT used here)
    ; --- wait, this is Burton's 1-byte variant ---
    ; We use the full 2-byte version:
    LD A, (BC)
    INC BC
    LD L, A
    ; HL = CFA address
    LD E, (HL)      ; fetch code field (low)
    INC HL
    LD D, (HL)      ; fetch code field (high)
    EX DE, HL       ; HL = handler address
    JP (HL)         ; dispatch
ENDM
```

Wait — reviewing both implementations:

**Burton's NEXT** (at 0x8145):
```
LD A,(BC); INC BC; LD L,A    ; fetch low byte -> L
LD A,(BC); INC BC; LD H,A    ; fetch high byte -> H
LD E,(HL); INC HL; LD D,(HL) ; read CFA contents into DE
EX DE,HL                      ; HL = handler
JP (HL)
```

**Hawg Wild's NEXT** (at 0x912F):
```
LD A,(BC); INC BC; LD H,A    ; fetch only HIGH byte -> H
LD E,(HL); INC HL; LD D,(HL) ; read CFA contents
EX DE,HL
JP (HL)
```

Hawg Wild uses a **single-byte high-page** scheme where all CFAs share the same
high byte (all code in one 256-byte page). This is a speed optimization but
constrains layout. We use **Burton's full 2-byte scheme** for flexibility.

### DOCOL (colon word entry)

```asm
DOCOL:
    ; Push BC (current IP) onto return stack
    LD HL, (RS_PTR)
    DEC HL
    DEC HL
    LD (HL), C
    INC HL
    LD (HL), B
    DEC HL
    LD (RS_PTR), HL
    ; Load new IP from PFA (word body follows CFA+2)
    ; On entry, HL still points to CFA+1 (from NEXT's INC HL before load)
    ; Actually: the calling word's thread had the CFA address; after JP(HL),
    ; HL = DOCOL. The PFA is at CFA+2.
    ; We need to get PFA. HL = DOCOL (us), not useful.
    ; Burton's approach: use BC to reconstruct PFA.
    ; See implementation notes.
    NEXT
```

### ;S (EXIT from colon word)

```asm
SEMI_S:
    ; Pop return stack into BC (restore IP)
    LD HL, (RS_PTR)
    LD C, (HL)
    INC HL
    LD B, (HL)
    INC HL
    LD (RS_PTR), HL
    NEXT
```

---

## Dictionary Structure

Standard fig-FORTH layout:

```
[LFA: 2 bytes]  Link Field Address — points to LFA of previous word
[NFA: 1+N bytes] Name Field — count byte (bits: IMM|SMG|len) + name chars
                              last char has bit 7 set
[CFA: 2 bytes]  Code Field — address of runtime handler (DOCOL, or machine code)
[PFA: N bytes]  Parameter Field — thread (colon words) or data (variables/constants)
```

### Word header macro

```asm
MACRO HEADER name, flags, label
    DW  PREV_WORD       ; LFA
    DB  (flags) | ($ - $$ - 3)  ; NFA count with flags  
    ; name string with high bit on last char
    DB  name_bytes...
label:
    ; CFA follows immediately
ENDM
```

---

## Word Set Plan

### ROM (0xC000-0xDFFF) — CODE words only

All `CODE` primitives (machine code bodies):
- Inner interpreter: NEXT, DOCOL, ;S, LIT, EXECUTE
- Branch/loop: BRANCH, 0BRANCH, (DO), (LOOP), (+LOOP), LEAVE, I
- Stack: DUP, DROP, SWAP, OVER, ROT, 2DUP, 2DROP, 2SWAP, >R, R>, R
- Arithmetic: +, -, MINUS, D+, DMINUS, U*, U/, *, /MOD, /, MOD
- Logic: AND, OR, XOR, 0=, 0<, =, <, U<, >
- Memory: @, !, C@, C!, 2@, 2!, +!
- I/O: EMIT, KEY, ?TERMINAL, CR
- String: CMOVE, (FIND), ENCLOSE, COUNT
- System: SP@, SP!, RP@, RP!, DIGIT, (NUMBER)

TS2068-specific CODE words (from Burton):
- LO, HI, RAM (bank switching)
- FEMIT, CURSOR (display)
- MS (millisecond delay)
- PORT@ (P@), PORT! (P!) 

Graphics CODE words (from Hawg Wild):
- EMIT/CR wrappers for TS2068 channel system
- BORDER, INK, PAPER, FLASH, BRIGHT (ROM calls)
- PLOT, DRAW (ROM calls)

### RAM image (copied from ROM on COLD start)

Colon definitions for:
- Compiler: :, ;, CREATE, DOES>, VARIABLE, CONSTANT, LITERAL
- Block I/O: BLOCK, BUFFER, UPDATE, FLUSH, LOAD, -->
- Formatting: <#, #, #S, #>, SIGN, D., D.R, ., .R, U.
- Disk: SEC-READ, SEC-WRITE, R/W, T&SCALC, SET-DRIVE
- Screen editor (from Hawg Wild): EDITOR, WHERE, H/E/S/D/M/T...
- Math: ABS, DABS, MIN, MAX, M*, M/, */MOD, */
- Tape: TAPE-SAVE, SCR-SAVE, SCR-LOAD
- Utilities: DUMP, DEPTH, NLIST, BEEP, STATUS, VLIST

---

## Build System

```
src/
  macros.asm      — NEXT, DOCOL, HEADER, ENTRY macros
  engine.asm      — inner interpreter, COLD/WARM/ABORT/QUIT
  primitives.asm  — all CODE words
  ts2068.asm      — TS2068-specific hardware words
  dictionary.asm  — ROM-resident colon definitions
  userwords.asm   — Hawg Wild additions
  main.asm        — top-level, ORG 0xC000, INCLUDEs everything

build/
  forth.bin       — 8192-byte raw cartridge binary
  forth.sym       — symbol table for debugging
```

**Build command:**
```
sjasmplus --raw=build/forth.bin --sym=build/forth.sym src/main.asm
```

---

## Source code standards

- All labels: `SNAKE_CASE` for internal, `FORTH_WORD_NAME` for dict entries
- Every Forth word has a comment block: stack effect, description
- NEXT appears as a macro call, never inlined except in tight loops
- TS2068 port addresses defined as named constants (no magic numbers)

---

## Phase plan

1. **Phase 1** — Inner interpreter + ~30 primitives, COLD/WARM, QUIT loop. Boots to `ok`.
2. **Phase 2** — Full arithmetic, memory, compiler words. Can define new words.
3. **Phase 3** — Block I/O, disk words. Can LOAD screens.
4. **Phase 4** — Hawg Wild additions: editor, graphics, float, tape.
5. **Phase 5** — TS2068 hardware words from Burton: RAM banking, printer, etc.

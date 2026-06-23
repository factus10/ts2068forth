# TS2068 fig-FORTH — Claude Code Project Context

## What this is

A new fig-FORTH implementation for the Timex/Sinclair 2068, targeting a 16K DOCK
cartridge ROM (chunks 4-5, $8000-$BFFF). Built from scratch in Z80 assembly using
sjasmplus, combining the best of two reference implementations:

- **Burton (Robert J. Burton, ~198x)** — clean engine, TS2068-native hardware words,
  public domain. Used as the base.
- **Hawg Wild Software (1985)** — screen editor, graphics, floating point via Spectrum
  ROM, tape I/O, extra utilities. Words to be ported in later phases.

Both reference TAP files were disassembled and their word lists compared. 232 words are
shared between them (the complete fig-FORTH kernel). Burton has 18 TS2068-specific
hardware words Hawg Wild lacks. Hawg Wild has ~66 additional words (editor, graphics,
float, tape) that Burton lacks.

## Current build state

**Builds cleanly. 258 words. ~9.4K code. ROM-safe (all mutable state in RAM).
Two build variants from the same source (differ only in DICT_RAM_START):**
- **Cartridge** (`.dck`): 16K dictionary at $C000 (since $8000-$BFFF is DOCK ROM).
- **RAM/tape** (`.tap`, `-DRAM_BUILD`): ~22K dictionary at $A800 (engine + dict both in
  RAM, so the user dict sits right above the engine — reclaims the RAM the cartridge ROM
  shadows). Banner shows 22272 free vs 16128.

```
make          # build build/forth.dck (cartridge) + build/forth-ram.tap (RAM, ~22K)
make dck      # just the .dck cartridge (DICT_RAM_START=$C000)
make ram      # just the RAM .tap (sjasmplus -DRAM_BUILD, DICT_RAM_START=$A800)
make verify   # run tools/verify.py sanity checks (on the cartridge build)
```

Code is ORG'd at $8000 (cartridge: DOCK chunks 4-5; RAM build: loaded into RAM at $8000).
`tools/mkdck.py` wraps the 16K cartridge image as an autostarting LROS `.dck`;
`tools/mktap.py` wraps the RAM image as a `.tap` (BASIC autoloader: CLEAR 32767, LOAD ""
CODE, RANDOMIZE USR 32768). ROM-safety verified via a ZEsarUX write-breakpoint over
$8000-$BFFF (silent through COLD+banner boot). NOTE: ZEsarUX loads the dock
chunks but does NOT emulate TS2068 LROS autostart, so the auto-boot must be
confirmed on real hardware (or by manually mapping HSR=$30 then JP $8000).

Requires: `sjasmplus` v1.22.0+ on PATH.
Install: `git clone https://github.com/z00m128/sjasmplus && cd sjasmplus && cmake . && make`

## Register conventions

| Register | Role |
|---|---|
| `(FORTH_IP)` | Instruction Pointer — **in memory** ($FA00 scratch page), NOT a register. BC is free for CODE words. |
| HL | Top of Parameter Stack (TOS), preserved across NEXT dispatch |
| SP | Parameter Stack pointer (grows down from 0xF600 = PS_TOP) |
| `(USER+44)` | Return stack pointer (USER area offset U_RS_PTR=44; RS grows down from 0xF800) |
| IY | **DO NOT TOUCH** — Spectrum interrupt handler uses it |
| BC | free scratch for CODE words |
| DE | scratch / used by NEXT to pass CFA+1 to DOCOL |

NEXT leaves DE = CFA+1 after dispatch, which DOCOL uses to find PFA = CFA+2.
IP lives in the `FORTH_IP` memory cell (relocated to the $FA00 RAM scratch page
for the cartridge — it must not be inline in ROM).

## CODE word cross-call pattern

CODE words end with `jp FORTH_NEXT` and can't be called via `call` from machine
code (they'd never return). Words that need to be callable from both threaded Forth
AND machine code use the `_MC_` pattern:

```
FOO_CODE:                   ; threaded entry (via FORTH_NEXT)
    call _MC_FOO
    jp  FORTH_NEXT
_MC_FOO:                    ; machine-code callable (via call/ret)
    ... body ...
    ret
```

20 words use this pattern. Machine-code callers (e.g. `_DO_INTERPRET`) call `_MC_FOO`
directly. All `call XXXX_CODE` cross-calls have been eliminated.

## Memory map

Cartridge layout (chunk-spec $CF → HSR NOT($CF)=$30: chunks 4-5 from DOCK, rest HOME):
```
0x0000-0x3FFF  HOME ROM (chunks 0-1, mapped — RST calls, charset, keyboard, RST $28 FP)
0x4000-0x5FFF  HOME RAM (chunk 2 — display file, system vars, SYSCON)
0x6000-0x6FFF  HOME RAM (chunk 3 lower — dispatcher/machine stack/CHANS; MUST stay HOME)
0x7000-0x73FF  Block buffers (1K, one 1024-byte block)        ] system block, relocated
0x7400-0x75FF  Parameter stack (grows down from 0x7600)        ] into the free part of
0x7600-0x77FF  Return stack (grows down from 0x7800)           ] chunk-3 RAM so the whole
0x7800-0x78FF  TIB (Terminal Input Buffer)                     ] of chunks 6-7 is dict.
0x7900-0x79BF  PAD (scratch area)                              ] ($7000-$7FFF verified
0x79C0-0x79FF  USER variables (64 bytes)                       ]  untouched by HOME ROM
0x7A00-0x7A42  Scratch sysvar page (FORTH_IP + ~28 cells)      ]  + keyboard IRQ.)
0x7B00-0x7B1E  EXROM tape bank-switch stub (copied at COLD)    ]
0x8000-0xBFFF  DOCK ROM  (chunks 4-5 — 16K Forth code image; ORG $8000)
0xC000-0xFFFF  RAM       (chunks 6-7 — Forth dictionary, 16K contiguous, grows up)
```
All mutable state is in RAM — nothing writable is inline in the ROM ($8000-$BFFF).
The dictionary now spans the entire 16K of chunks 6-7 ($C000-$FFFF); the small system
block was moved down into chunk-3 RAM ($7000-$7BFF) to free it (v0.7).

## Source file map

```
src/main.asm        Top-level: ORG 0xC000, INCLUDE chain, ROM fill/check
src/ts2068.inc      ALL hardware constants: ports, ROM addresses, sysvar addrs,
                    memory map EQUs, USER variable offsets (U_BASE, U_DP, etc.)
src/macros.inc      sjasmplus macros: GOTO_NEXT, PUSH_TOS, POP_TOS,
                    RPUSH_BC, RPOP_BC, RPUSH_HL, RPOP_HL, RPOP_DE, LFA_EMIT
src/engine.asm      FORTH_NEXT, FORTH_DOCOL, FORTH_SEMIS, FORTH_DOVAR,
                    FORTH_DOCON, FORTH_DOUSER, FORTH_DODOES,
                    FORTH_COLD, FORTH_WARM, FORTH_ABORT, FORTH_QUIT_MC,
                    _DO_QUERY, _GET_KEY, _PRINT_STR, USER init table
src/primitives.asm  All CODE words: stack, arithmetic, logic, memory,
                    I/O, string ops, dictionary ops, USER variables,
                    constants. ~90 words.
src/dictionary.asm  Compiler words, number I/O, control flow compilers,
                    defining words (CREATE/VARIABLE/CONSTANT),
                    INTERPRET (stubbed), QUIT/ABORT/WARM/COLD dict entries,
                    block I/O stubs, BYE. ~104 words.
src/ts2068hw.asm    TS2068 hardware: P@ P! BORDER CLS BEEP MS AT PLOT DRAW
                    INK PAPER BRIGHT FLASH; FP: INT>F F>INT F+ F- F* F/
                    FNEGATE FSQRT FSIN FCOS FTAN FLN FEXP FABS FDUP
                    FDROP FSWAP F.; tape: TSAVE TLOAD SAVE-BUFFERS
                    LOAD-BUFFERS
src/userwords.asm   Utils: FILL ERASE DUMP .S WORDS ." .( EXPECT DOES>
                    FORGET --> NEGATE TRUE FALSE WITHIN MOVE [COMPILE]
                    RECURSE ' ['];  editor: LINE T P D I CLEAR L
```

## Dictionary structure

Each word:
```
W_NAME:  dw  _LINK          ; LFA: points to previous word's LFA address
_LINK = W_NAME              ; update chain (MUST be at column 0)
         db  len, "NAM", 'E'|0x80  ; NFA: count byte + name, last char OR 0x80
NAME:    dw  HANDLER        ; CFA: address of runtime handler
; code or thread follows (PFA)
```

`_LINK` starts at 0 in primitives.asm and threads through all files.
The final value of `_LINK` after all includes = LFA of the last defined word.

## sjasmplus quirks (critical)

1. `macro`/`endm` keywords **must be indented** — at column 0 they're treated as labels
2. Variable assignments (`_LINK = W_FOO`) **must be at column 0** — indented = error
3. Labels **cannot start with a digit** — `0BRANCH` → `ZBRANCH`, `2DUP` → `DDUP`, etc.
4. `LD (DE), r` is **illegal Z80** — always route through A: `LD A, r : LD (DE), A`
5. `LD HL, (HL)` is **illegal** — use `LD E,(HL) : INC HL : LD D,(HL) : EX DE,HL`
6. `LD (DE), 0` is **illegal** — use `XOR A : LD (DE), A`

## Phase plan

| Phase | Status | Description |
|---|---|---|
| 1 | ✓ Done | Inner interpreter, COLD/WARM/ABORT, ~55 primitives, machine-code QUIT |
| 2 | ✓ Done | Compiler words, number I/O, control flow, CREATE/VARIABLE/CONSTANT |
| 3 | Done | Fix INTERPRET, -FIND, (NUMBER), WORD; get `ok` prompt working |
| 4 | Done | TS2068 hw, graphics, block I/O, utilities, screen editor, tape I/O |
| 5 | Done | Floating point (18 words), standard words (NEGATE, TRUE, FALSE, ', ['], [COMPILE], RECURSE, MOVE, WITHIN) |

## Phase 3 completed

All Phase 3 items have been implemented:

1. **INTERPRET** — full outer interpreter in `_DO_INTERPRET` (engine.asm). Processes
   all tokens in TIB: dictionary lookup, execute/compile, number parsing. Uses a
   trampoline (`INTERP_RESUME`) to enter/exit threaded mode for word execution.
2. **-FIND** — dictionary search walks LFA chain from CONTEXT vocab, compares counted
   strings with smudge-bit checking. Also has `_DICT_SEARCH` subroutine shared with
   `_DO_INTERPRET`.
3. **WORD** — rewritten to properly update `>IN`, write counted string at HERE with
   high-bit convention on last char. Block input path deferred (falls back to TIB).
4. **`:` (colon)** — now calls WORD→CREATE→emit DOCOL→STATE=1→SMUDGE→!CSP.
5. **(NUMBER)** — fixed hex letter conversion (was masking char-'0' instead of char)
   and replaced broken shift-multiply with EXX-based 32-bit multiply.
6. **U.** — fixed stack setup: push u as d_low, set d_high=0, then `<# #S #> TYPE`.

Additional fixes made:
- **COMMA** — was storing only low byte; now stores both bytes and advances DP by 2.
- **CONTEXT/CURRENT init** — COLD now initializes vocab head cell at DICT_RAM_START
  with NFA of last ROM word (W_BYE+2). CONTEXT and CURRENT point to this cell.
  DP starts at DICT_RAM_START+2.
- **U/** — implemented proper 32/16 restoring division algorithm.
- **`#` (HASH)** — implemented proper two-step 32-bit divide by BASE for digit extraction.
- **`#>` (HASHB)** — fixed addr/len stack order.
- **CREATE** — rewritten to read name from HERE (where WORD puts it), shift name right
  by 2 bytes to insert LFA, update CURRENT vocab head.

## Known issues / remaining work

- **Cartridge autostart** — built & header-correct, but unverified on real hardware
  (ZEsarUX loads dock chunks but doesn't emulate LROS autostart). Verify on a real
  TS2068 or by manually setting HSR=$30 and jumping to $8000.
- **Tape I/O** — IMPLEMENTED (cartridge-safe), UNVERIFIED on hardware. TSAVE/TLOAD/
  SAVE-BUFFERS/LOAD-BUFFERS route through `_MC_TAPE_SAVE`/`_MC_TAPE_LOAD` (ts2068hw.asm),
  which page the 8K EXROM into chunk 0 only (HSR=$31 + DECR bit 7) — chunks 4-5 (our
  code) and 6-7 (RAM/stacks) stay mapped, so it runs from cartridge ROM with no stub.
  Calls W_TAPE $0068 / R_TAPE $00FC. Buffer (IX) must be ≥$C000 (never chunk 0/1).
  Couldn't be runtime-tested headless (needs real hardware or ZEsarUX tape + key input).
- **DOES> / CREATE / VARIABLE / CONSTANT / USER** — FIXED (v0.5/v0.6). DOES> uses the proper
  ITC (;CODE)+CALL DODOES mechanism; CREATE/VARIABLE/CONSTANT/USER now parse their name (they
  called _MC_CREATE without _MC_WORD before). Verified: `: K CREATE , DOES> @ ; 5 K FIVE FIVE .`
  →5; `VARIABLE V 42 V ! V @ .`→42; `99 CONSTANT N N .`→99.
- **VOCABULARY/FORTH** — still simplified (creates a DOVAR word, parses name; not the full
  fig vocabulary model). See Advanced Spectrum FORTH entries 224-228.
- **LOAD** — has its own interpreter loop (duplicated from _DO_INTERPRET).
- **Floating point** — uses ROM calculator (RST $28); still works (HOME ROM stays mapped).
- **WITHIN / MOVE** — DONE (userwords.asm). WITHIN does `(n-lo) u< (hi-lo)`; MOVE chooses
  LDIR/LDDR by direction. (Earlier "stubbed/forward-only" notes were stale.)

## Key addresses

Run `grep 'SYMBOLNAME' build/forth.sym` for exact addresses.
Key symbols: FORTH_NEXT, FORTH_DOCOL, FORTH_SEMIS, FORTH_COLD, FORTH_WARM,
FORTH_ABORT, LIT, BRANCH, ZBRANCH, DUP, EMIT, KEY, CREATE, INTERPRET.

Note: code lives at 0x8000-0xBFFF (cartridge ROM window).

## Testing with ZEsarUX

**See [docs/zesarux-debugging-guide.md](docs/zesarux-debugging-guide.md) for the full
debugging playbook** — ZRCP recipes, the decimal-vs-hex address trap, the one-line
poke-test for driving the interpreter, screen rendering, breakpoints, and why Fuse (not
ZEsarUX) is the authoritative oracle for the LROS cartridge. Highlights:

RAM smoke test (ZRCP, no tape — fastest dev loop):
```
/Applications/zesarux.app/Contents/MacOS/zesarux --machine TS2068 --enable-remoteprotocol --noconfigfile
echo "load-binary /path/to/build/forth.bin 32768 0" | nc -w 2 localhost 10000
echo "set-register PC=8000h" | nc -w 2 localhost 10000   # jumps to CART_ENTRY
```
Render the screen: `save-screen /tmp/x.scr` then a Spectrum-.scr→PNG renderer
(6144 bitmap + interleaved layout), or `get-ocr` for screen text.

ROM-safety check: `set-breakpoint 1 MWA>=8000h and MWA<=BFFFh` — must NOT fire
during a session (no writes into the ROM window).

Cartridge: `make dck` then load build/forth.dck. ZEsarUX inserts the dock chunks
(smartload by .dck extension) but does NOT emulate LROS autostart — to see it boot,
manually map HSR ($F4=$30) and JP $8000. Real autostart needs hardware/another emu.

Caveat: ZRCP send-keys-* did not reach this Forth's keyboard read in headless tests
(LAST_K unchanged); interactive testing currently needs the ZEsarUX window focused.

## TS2068 Reference Library

Architecture docs, ROM disassemblies, and reference cartridge code are in:
`/Users/david/Documents/Projects/TS2068 Ref Library/`
See its CLAUDE.md for an index of docs (memory map, system variables, dispatcher API, etc.).

## Reference material

- Both reference TAP files were analyzed in Claude.ai before this project started
- Burton's NEXT: BC=IP, HL=TOS, DE=CFA+1 after dispatch (same as ours)
- Hawg Wild's NEXT uses single-byte high-page trick (we don't, for flexibility)
- fig-FORTH standard: `https://forth.org/` — the 1979 fig-FORTH model
- Z80 instruction set reference: any standard Z80 datasheet
- TS2068 Technical Manual: Timex Computer Corp., 1983

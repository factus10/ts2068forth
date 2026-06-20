# TS2068 fig-FORTH

A from-scratch [fig-FORTH](https://en.wikipedia.org/wiki/Forth_(programming_language)#FIG-Forth)
for the **Timex/Sinclair 2068**, delivered as an autostarting **16K LROS DOCK cartridge**.
Written in Z80 assembly (sjasmplus). Boots straight to a Forth `ok` prompt — no BASIC, no tape load.

## Status

**Working cartridge (v0.7).** Confirmed booting and running on real-hardware-class emulation (Fuse).

- 258 words — the full fig-FORTH kernel plus TS2068 hardware words, floating point
  (via the ROM calculator), a block/screen editor, and tape I/O.
- ~9.4K of the 16K cartridge used; **16K contiguous RAM dictionary** (`$C000-$FFFF`).
- Runs entirely from ROM (all mutable state relocated to RAM) — `CREATE`/`VARIABLE`/`CONSTANT`/`USER`/`DOES>` defining words all work.

## Quick start

Requires `sjasmplus` 1.22.0+ on your PATH:

```bash
git clone https://github.com/z00m128/sjasmplus
cd sjasmplus && cmake . && make && sudo cp sjasmplus /usr/local/bin
```

Build and run:

```bash
make            # -> build/forth.dck (cartridge) + build/forth.tap + build/forth.bin
make verify     # sanity checks on the built image

# Run the cartridge in Fuse (autostarts to the Forth prompt):
fuse --machine 2068 build/forth.dck
```

Then try:

```forth
1 2 + .                       \ 3
: SQUARE  DUP * ;  7 SQUARE .  \ 49
VARIABLE X  42 X !  X @ .      \ 42
WORDS                          \ list the dictionary
```

## Memory map (cartridge)

| Range | Contents |
|---|---|
| `$0000-$3FFF` | HOME ROM (RST handlers, char set, keyboard, RST $28 FP) |
| `$4000-$5FFF` | display file + system variables |
| `$6000-$6FFF` | TS2068 OS dispatcher / stack / channels |
| `$7000-$7BFF` | Forth system block (stacks, TIB, PAD, USER vars, scratch, tape stub) |
| `$8000-$BFFF` | **DOCK ROM — the 16K Forth cartridge image** |
| `$C000-$FFFF` | **16K RAM dictionary** (grows up) |

The cartridge maps chunks 4-5 from the DOCK (chunk-spec `$CF` → HSR `$30`); everything
else stays HOME. See [`CLAUDE.md`](CLAUDE.md) and [`docs/`](docs/) for the full technical
documentation, including the LROS boot mechanism and a ZEsarUX/Fuse debugging guide.

## Source layout

```
src/main.asm        ORG $8000, include chain, LROS entry
src/engine.asm      inner interpreter (NEXT/DOCOL/...), COLD/WARM, INTERPRET, dict search
src/primitives.asm  CODE words: stack, arithmetic, logic, memory, I/O
src/ts2068hw.asm    TS2068 hardware: graphics, floating point, tape I/O
src/dictionary.asm  compiler, number I/O, control flow, defining words
src/userwords.asm   utilities, DOES>, FORGET, screen editor, standard words
src/ts2068.inc      hardware/memory-map constants
tools/mkdck.py      wrap the 16K image as an autostarting .dck cartridge
tools/mktap.py      make a RAM/tape .tap for quick testing
tools/verify.py     build sanity checks
```

## Credits & license

Built from scratch, informed by analysis of:
- Robert J. Burton's fig-FORTH for the TS2068 (~198x, public domain)
- Hawg Wild Software's fig-FORTH for the TS2068 (1985)

Public domain / open source, in the spirit of the original fig-FORTH model.

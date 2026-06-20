#!/usr/bin/env python3
"""Create a .dck (Warajevo DOCK cartridge) file from the raw Forth ROM binary.

This builds an autostarting LROS cartridge for the TS2068.

How the TS2068 launches an LROS (verified from the EXROM disassembly,
BLDSCT / GOTO_BANK / BANK_ENABLE):

  * At power-on the EXROM copies 4 bytes from DOCK $0001-$0004 to SYSCON+8.
    If byte $0001 == $01 it is an LROS.
      $0001 = $01            LROS type marker
      $0002 = entry LSB
      $0003 = entry MSB
      $0004 = chunk-spec     (low-active: bit N = 0 -> chunk N from cartridge)
  * GOTO_BANK runs BANK_ENABLE, which writes HSR = NOT(chunk-spec) to port $F4,
    disables the EXROM, and JUMPS to the entry address. So banks are already
    correct on entry -- no RAM trampoline is needed.

Our config: chunk-spec $EF -> HSR $30 -> chunks 4-5 ($8000-$BFFF) come from the
cartridge; chunks 0-3 stay HOME ROM (print/keyboard/FP) and chunks 6-7 stay RAM
(dictionary + stacks). The OS jumps straight to our $8000 entry (= CART_ENTRY).

DCK container (Warajevo): per bank a 9-byte header
  byte 0:    bank ID (0=DOCK, 254=EXROM, 255=HOME)
  bytes 1-8: chunk type per 8K chunk (0=null, 1=RAM empty, 2=ROM, 3=RAM+data)
followed by 8192 bytes for each non-null chunk.
"""
import sys

LROS_TYPE   = 0x01
ENTRY_ADDR  = 0x8000   # CART_ENTRY (start of the ROM image)
CHUNK_SPEC  = 0xCF     # low-active: bits 4,5 = 0 -> chunks 4,5 from cartridge.
                       # The OS writes HSR = NOT(chunk-spec) = NOT($CF) = $30,
                       # mapping BOTH $8000-$9FFF and $A000-$BFFF from the DOCK.
                       # ($EF was wrong: NOT($EF)=$10 maps only chunk 4, leaving
                       #  the dictionary's chunk-5 tail unmapped -> lookups fail.)
CHUNK_SIZE  = 8192

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} input.bin output.dck")
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    rom = f.read()

if len(rom) > 2 * CHUNK_SIZE:
    print(f"Error: ROM image is {len(rom)} bytes, exceeds 16384 (chunks 4-5)")
    sys.exit(1)

# Pad the code image up to a full 16K (chunks 4-5) with $FF.
rom = rom + b'\xff' * (2 * CHUNK_SIZE - len(rom))

# --- Chunk 0: LROS header only (no code, no trampoline) ----------------------
chunk0 = bytearray(b'\xff' * CHUNK_SIZE)
chunk0[0x0000] = 0x00                    # unused
chunk0[0x0001] = LROS_TYPE               # LROS marker
chunk0[0x0002] = ENTRY_ADDR & 0xFF       # entry LSB
chunk0[0x0003] = (ENTRY_ADDR >> 8) & 0xFF  # entry MSB
chunk0[0x0004] = CHUNK_SPEC              # chunk specification

# --- DCK file: DOCK bank, chunk 0 = ROM (header), chunks 4-5 = ROM (Forth) ---
header = bytes([
    0x00,                       # bank = DOCK
    0x02,                       # chunk 0: ROM (LROS header)
    0x00, 0x00, 0x00,           # chunks 1-3: null
    0x02, 0x02,                 # chunks 4-5: ROM (Forth code)
    0x00, 0x00,                 # chunks 6-7: null (HOME RAM at runtime)
])

with open(sys.argv[2], 'wb') as f:
    f.write(header)
    f.write(bytes(chunk0))      # chunk 0 (8K)
    f.write(rom)                # chunks 4-5 (16K)

print(f"Created {sys.argv[2]}: {len(header) + CHUNK_SIZE + len(rom)} bytes")
print(f"  Chunk 0:    LROS header  [01 {ENTRY_ADDR & 0xFF:02X} {ENTRY_ADDR >> 8:02X} {CHUNK_SPEC:02X}] at $0001")
print(f"  Chunks 4-5: Forth ROM (16K, padded), entry ${ENTRY_ADDR:04X}")
print(f"  Boot: EXROM detects LROS -> HSR=$30 (chunks 4-5 from DOCK) -> JP ${ENTRY_ADDR:04X}")

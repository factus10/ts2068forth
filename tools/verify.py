#!/usr/bin/env python3
"""Quick sanity check on the built binary."""
import sys

syms = {}
with open('build/forth.sym') as f:
    for line in f:
        if ': EQU ' in line:
            n, v = line.split(': EQU ')
            syms[n.strip()] = int(v.strip(), 16)

BASE = 0x8000   # cartridge ROM origin (DOCK chunks 4-5)
with open('build/forth.bin', 'rb') as f:
    rom = f.read()

errors = 0

def check(cond, msg):
    global errors
    if not cond:
        print(f"FAIL: {msg}")
        errors += 1
    else:
        print(f"OK:   {msg}")

used = len(rom)
check(used <= 16384, f"Code fits in 16K ({used}/16384 bytes, {used/16384*100:.1f}%)")

# Entry point at offset 0
check(rom[0] == 0xF3, "Entry point starts with DI")
check(rom[1] == 0x31, "Entry point: LD SP,nn")

fn = syms.get('FORTH_NEXT')
# IP-in-memory NEXT: push hl; ld hl,(FORTH_IP); ...
expected_start = bytes([0xE5, 0x2A])  # PUSH HL; LD HL,(nn)
check(fn and rom[fn-BASE:fn-BASE+2] == expected_start, "FORTH_NEXT starts with PUSH HL; LD HL,(IP)")

dup = syms.get('DUP_CODE')
check(dup and rom[dup-BASE] == 0xE5, "DUP_CODE starts with PUSH HL")

words = sum(1 for k in syms if k.startswith('W_'))
check(words >= 180, f"At least 180 words defined (got {words})")

print(f"\n{'PASS' if errors==0 else 'FAIL'}: {errors} error(s)")
sys.exit(errors)

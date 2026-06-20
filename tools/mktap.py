#!/usr/bin/env python3
"""Create a .tap file with BASIC auto-loader + CODE block for TS2068 fig-FORTH.

This is a SECONDARY artifact for loading the (re-ORG'd $8000) image into RAM for
quick tests; the primary deliverable is the .dck cartridge (tools/mkdck.py).

The BASIC loader does:
  10 CLEAR 32767
  20 LOAD "" CODE
  30 RANDOMIZE USR 32768
"""
import sys, struct

if len(sys.argv) != 3:
    print(f"Usage: {sys.argv[0]} input.bin output.tap")
    sys.exit(1)

with open(sys.argv[1], 'rb') as f:
    code = f.read()

code_addr = 0x8000  # 32768 — matches the cartridge ROM origin
code_len = len(code)


def xor_checksum(data):
    c = 0
    for b in data:
        c ^= b
    return c


def tap_block(flag, data):
    payload = bytes([flag]) + data
    chk = xor_checksum(payload)
    payload += bytes([chk])
    return struct.pack('<H', len(payload)) + payload


def make_header(type_byte, filename, data_len, param1, param2):
    name = filename.encode('ascii')[:10].ljust(10)
    return bytes([type_byte]) + name + struct.pack('<HHH', data_len, param1, param2)


def basic_number(value):
    """Encode a number in Spectrum BASIC's inline format:
    0x0E followed by 5 bytes of FP representation for integers."""
    # For integers 0-65535: sign=0, exponent=0, low byte, high byte, 0
    return bytes([0x0E, 0x00, 0x00,
                  value & 0xFF, (value >> 8) & 0xFF, 0x00])


def basic_line(line_num, tokens):
    """Build a BASIC line: 2-byte line number (big-endian),
    2-byte length (little-endian), token bytes, 0x0D terminator."""
    body = tokens + b'\x0D'
    return struct.pack('>H', line_num) + struct.pack('<H', len(body)) + body


# Build BASIC program lines
# Token values: CLEAR=0xFD, LOAD=0xEF, CODE=0xAF, RANDOMIZE=0xF9, USR=0xC0
# Quote=0x22, colon=0x3A

# 10 CLEAR 32767
line10 = basic_line(10,
    b'\xFD'                          # CLEAR
    b'32767' + basic_number(32767))  # number as text + inline FP

# 20 LOAD ""CODE
line20 = basic_line(20,
    b'\xEF'             # LOAD
    b'\x22\x22'         # ""
    b'\xAF')            # CODE

# 30 RANDOMIZE USR 32768
line30 = basic_line(30,
    b'\xF9'                          # RANDOMIZE
    b'\xC0'                          # USR
    b'32768' + basic_number(32768))  # number as text + inline FP

basic_prog = line10 + line20 + line30
autostart_line = 10

# TAP structure:
# 1. BASIC header (type 0x00 = Program)
# 2. BASIC data block
# 3. CODE header (type 0x03 = Bytes)
# 4. CODE data block

basic_header = make_header(0x00, "FORTH", len(basic_prog),
                           autostart_line, len(basic_prog))
code_header = make_header(0x03, "FORTH", code_len,
                          code_addr, 32768)

tap = b''
tap += tap_block(0x00, basic_header)   # BASIC header
tap += tap_block(0xFF, basic_prog)     # BASIC data
tap += tap_block(0x00, code_header)    # CODE header
tap += tap_block(0xFF, code)           # CODE data

with open(sys.argv[2], 'wb') as f:
    f.write(tap)

print(f"Created {sys.argv[2]}: {len(tap)} bytes")
print(f"  BASIC loader: {len(basic_prog)} bytes (auto-run line {autostart_line})")
print(f"  CODE block: {code_len} bytes at ${code_addr:04X}")
print(f"  Auto-loads and runs — just LOAD \"\"")

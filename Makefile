# TS2068 fig-FORTH Makefile
SJASMPLUS = sjasmplus
SRC       = src/main.asm

# Cartridge build: 16K dictionary at $C000 ($8000-$BFFF is DOCK ROM)
BIN       = build/forth.bin
DCK       = build/forth.dck
SYM       = build/forth.sym
LST       = build/forth.lst

# RAM/tape build (-DRAM_BUILD): engine AND dictionary both in RAM, so the
# dictionary starts just above the engine -> ~22K (vs 16K for the cartridge).
RAMBIN    = build/forth-ram.bin
RAMTAP    = build/forth-ram.tap
RAMSYM    = build/forth-ram.sym

all: $(DCK) $(RAMTAP)

# --- cartridge (.dck) ---
$(BIN): src/*.asm src/*.inc
	$(SJASMPLUS) --raw=$(BIN) --sym=$(SYM) --lst=$(LST) $(SRC)

$(DCK): $(BIN)
	python3 tools/mkdck.py $(BIN) $(DCK)

dck: $(DCK)

# --- RAM/tape (full-memory, ~22K dictionary) ---
$(RAMBIN): src/*.asm src/*.inc
	$(SJASMPLUS) -DRAM_BUILD --raw=$(RAMBIN) --sym=$(RAMSYM) $(SRC)

$(RAMTAP): $(RAMBIN)
	python3 tools/mktap.py $(RAMBIN) $(RAMTAP)

ram: $(RAMTAP)

clean:
	rm -f build/forth*.bin build/forth*.tap build/forth*.dck build/forth*.sym build/forth*.lst

verify: $(BIN)
	python3 tools/verify.py

.PHONY: all clean verify dck ram

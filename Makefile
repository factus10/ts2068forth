# TS2068 fig-FORTH Makefile
SJASMPLUS = sjasmplus
SRC       = src/main.asm
BIN       = build/forth.bin
TAP       = build/forth.tap
DCK       = build/forth.dck
SYM       = build/forth.sym
LST       = build/forth.lst

# Primary deliverable is the .dck cartridge; the .tap is for RAM/tape testing.
all: $(DCK) $(TAP)

$(BIN): src/*.asm src/*.inc
	$(SJASMPLUS) --raw=$(BIN) --sym=$(SYM) --lst=$(LST) $(SRC)

$(DCK): $(BIN)
	python3 tools/mkdck.py $(BIN) $(DCK)

$(TAP): $(BIN)
	python3 tools/mktap.py $(BIN) $(TAP)

dck: $(DCK)

clean:
	rm -f $(BIN) $(TAP) $(DCK) $(SYM) $(LST)

verify: $(BIN)
	python3 tools/verify.py

.PHONY: all clean verify dck

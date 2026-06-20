# TS2068 fig-FORTH Manual

**Version 0.1 — Public Domain / Open Source**

A complete guide to programming in Forth on the Timex/Sinclair 2068.

---

## Table of Contents

1. [What is Forth?](#1-what-is-forth)
2. [Getting Started](#2-getting-started)
3. [The Stack](#3-the-stack)
4. [Arithmetic](#4-arithmetic)
5. [Printing Numbers](#5-printing-numbers)
6. [Defining New Words](#6-defining-new-words)
7. [Stack Manipulation](#7-stack-manipulation)
8. [Conditionals (IF/THEN/ELSE)](#8-conditionals)
9. [Loops](#9-loops)
10. [Variables and Constants](#10-variables-and-constants)
11. [Memory Access](#11-memory-access)
12. [Strings and Text](#12-strings-and-text)
13. [The Dictionary](#13-the-dictionary)
14. [Number Bases](#14-number-bases)
15. [The Return Stack](#15-the-return-stack)
16. [Defining Words with DOES>](#16-defining-words-with-does)
17. [Block Editor and Screen Programming](#17-block-editor)
18. [TS2068 Graphics and Sound](#18-ts2068-graphics-and-sound)
19. [Floating-Point Mathematics](#19-floating-point)
20. [Tape I/O](#20-tape-io)
21. [Error Handling](#21-error-handling)
22. [Programming Techniques](#22-programming-techniques)
23. [Example Programs](#23-example-programs)
24. [Complete Word Reference](#24-complete-word-reference)

---

## 1. What is Forth?

Forth is a programming language invented by Charles Moore in the late 1960s. It is
unlike most languages you may have encountered. Where BASIC says:

```basic
PRINT 3 + 4
```

Forth says:

```forth
3 4 + .
```

That looks strange at first. Why does the `+` come *after* the numbers? Because Forth
uses a **stack** — a last-in, first-out data structure — as its primary mechanism for
passing data between operations. You push numbers onto the stack, then operations
consume them and push results back.

Forth has several distinctive qualities:

- **Interactive.** You type commands and see results immediately. There is no
  separate compile-edit-run cycle.
- **Extensible.** Every new word (function) you define becomes part of the language
  itself, indistinguishable from built-in words.
- **Tiny.** The entire Forth system fits in under 9K of memory — remarkable for a
  language with an interactive compiler, editor, and over 250 built-in words.
- **Fast.** Forth runs close to the speed of hand-written machine code on the Z80.
- **Simple.** The core language has very few rules. Everything is built from those
  few rules.

### The Forth Philosophy

Forth encourages you to **factor** your programs into many small, well-tested words.
Rather than writing one long program, you build a vocabulary of words, each doing one
thing well, then combine them. A finished Forth program reads almost like English:

```forth
: GREET   ." Hello, world!" CR ;
: MAIN    CLS GREET ;
```

---

## 2. Getting Started

### Loading TS2068 fig-FORTH

Load the `forth.tap` file from tape (or via emulator). The BASIC loader will
automatically start the Forth system. You will see:

```
TS2068 fig-FORTH  v0.1
Public Domain / Open Source
```

followed by a blinking cursor. This is the Forth **ok** prompt — the system is
waiting for you to type something.

### Your First Interaction

Type the following and press ENTER:

```forth
1 2 + .
```

You should see:

```
3 ok
```

Congratulations — you just ran your first Forth program. Here is what happened:

| You typed | What it did |
|-----------|------------|
| `1` | Pushed the number 1 onto the stack |
| `2` | Pushed the number 2 onto the stack |
| `+` | Popped two numbers, added them, pushed 3 |
| `.` | Popped and printed the top number (3) |

The `ok` at the end means Forth successfully processed everything you typed.

### Errors

If you type something Forth does not understand, it prints `?` and returns to
the prompt:

```
blurgh ?
```

This means `blurgh` was not found in the dictionary and could not be parsed as a
number. Forth resets the stack and waits for your next input.

---

## 3. The Stack

The stack is Forth's central concept. Think of it as a pile of numbers. You can
only access the top. When you type a number, it goes on top. When an operation
runs, it takes numbers from the top and puts results back on top.

### Stack Notation

Forth documents the effect of every word using **stack notation**:

```
( before -- after )
```

The items before `--` are consumed from the stack (top of stack is rightmost).
The items after `--` are left on the stack.

Examples:

| Word | Stack effect | Meaning |
|------|-------------|---------|
| `+` | `( a b -- sum )` | Add top two numbers |
| `.` | `( n -- )` | Print and remove top number |
| `DUP` | `( n -- n n )` | Duplicate the top number |
| `DROP` | `( n -- )` | Discard the top number |
| `SWAP` | `( a b -- b a )` | Exchange top two numbers |

### Experimenting with the Stack

```forth
5 3 .        ( prints 3, leaves 5 )
.            ( prints 5, stack is now empty )
```

Comments in Forth are enclosed in parentheses: `( like this )`. Note the space
after `(` — it is a Forth word, not syntax. Everything between `(` and `)` is
ignored.

```forth
10 20 30 .S
```

`.S` prints the entire stack without removing anything. You should see the three
numbers listed.

### Stack Underflow

If you try to use more items than the stack contains, the result is undefined.
Forth does not check for stack underflow (this is normal for fig-FORTH). Be
careful to keep track of what is on the stack.

---

## 4. Arithmetic

### Basic Operations

| Word | Stack | Description |
|------|-------|-------------|
| `+` | `( a b -- a+b )` | Addition |
| `-` | `( a b -- a-b )` | Subtraction |
| `*` | `( a b -- a*b )` | Multiplication |
| `/` | `( a b -- a/b )` | Division (integer, truncated) |
| `MOD` | `( a b -- a-mod-b )` | Remainder after division |
| `/MOD` | `( a b -- rem quot )` | Remainder and quotient |
| `MINUS` | `( n -- -n )` | Negate |
| `ABS` | `( n -- |n| )` | Absolute value |
| `MIN` | `( a b -- min )` | Smaller of two |
| `MAX` | `( a b -- max )` | Larger of two |

All arithmetic is **16-bit signed integer**, giving a range of -32768 to 32767.

### Examples

```forth
7 3 / .          ( prints 2 — integer division )
7 3 MOD .        ( prints 1 — remainder )
7 3 /MOD . .     ( prints 2 then 1 — quotient then remainder )
-5 ABS .         ( prints 5 )
3 7 MIN .        ( prints 3 )
```

### Double-Length Arithmetic

Some operations work with 32-bit **double-length** numbers, which occupy two
stack cells (low word on stack, high word on top):

| Word | Description |
|------|-------------|
| `D+` | Double addition |
| `DMINUS` | Double negate |
| `DABS` | Double absolute value |
| `U*` | Unsigned 16x16 multiply giving 32-bit result |
| `U/` | Unsigned 32/16 divide giving 16-bit quotient and remainder |
| `M*` | Mixed (signed) multiply |
| `M/` | Mixed (signed) divide |
| `*/` | Scale: `( a b c -- a*b/c )` with 32-bit intermediate |
| `*/MOD` | Like `*/` but also returns remainder |

### Comparison

| Word | Stack | True if... |
|------|-------|------------|
| `=` | `( a b -- flag )` | a equals b |
| `<` | `( a b -- flag )` | a less than b (signed) |
| `>` | `( a b -- flag )` | a greater than b (signed) |
| `U<` | `( a b -- flag )` | a less than b (unsigned) |
| `0=` | `( n -- flag )` | n is zero |
| `0<` | `( n -- flag )` | n is negative |

In Forth, **true** is -1 (all bits set, $FFFF) and **false** is 0.

```forth
3 4 = .      ( prints 0 — false )
3 3 = .      ( prints -1 — true )
5 0< .       ( prints 0 — 5 is not negative )
```

### Logic

| Word | Stack | Description |
|------|-------|-------------|
| `AND` | `( a b -- a-and-b )` | Bitwise AND |
| `OR` | `( a b -- a-or-b )` | Bitwise OR |
| `XOR` | `( a b -- a-xor-b )` | Bitwise XOR |
| `NOT` | `( a -- not-a )` | Bitwise complement (one's complement) |

---

## 5. Printing Numbers

| Word | Stack | Description |
|------|-------|-------------|
| `.` | `( n -- )` | Print signed number with trailing space |
| `U.` | `( u -- )` | Print unsigned number with trailing space |
| `D.` | `( d -- )` | Print signed double number |
| `.R` | `( n w -- )` | Print n right-justified in w columns |
| `CR` | `( -- )` | Print a carriage return (new line) |
| `SPACE` | `( -- )` | Print one space |
| `SPACES` | `( n -- )` | Print n spaces |
| `EMIT` | `( c -- )` | Print a single character (by ASCII code) |

### Examples

```forth
42 .             ( prints "42 " )
65 EMIT          ( prints "A" — ASCII 65 )
CR               ( new line )
10 0 DO I . LOOP ( prints "0 1 2 3 4 5 6 7 8 9 " )
```

### Number Output Formatting

For full control over number formatting, use the **pictured numeric output** words:

```forth
<#     ( -- )          Begin formatting
#      ( d -- d' )     Extract one digit
#S     ( d -- 0 0 )    Extract all remaining digits
SIGN   ( n -- )        Add minus sign if n is negative
#>     ( d -- addr n ) End formatting, return string address and length
HOLD   ( c -- )        Insert character into formatted output
```

Example — print a number with a leading `$`:

```forth
: DOLLAR   ( n -- )
   DUP ABS 0        ( convert to double )
   <# #S SIGN       ( extract digits and sign )
   36 HOLD           ( insert $ — ASCII 36 )
   #> TYPE SPACE ;

-42 DOLLAR           ( prints "$-42 " )
```

---

## 6. Defining New Words

The `:` (colon) word begins a new definition. The `;` (semicolon) ends it.

```forth
: SQUARE   ( n -- n*n )   DUP * ;
```

This defines a new word called `SQUARE` that duplicates the top of stack and
multiplies. Now you can use it:

```forth
7 SQUARE .           ( prints 49 )
```

### Building Vocabulary

Forth programs are built by defining words in terms of other words:

```forth
: SQUARE   DUP * ;
: CUBE     DUP SQUARE * ;
: SUM-OF-SQUARES   ( a b -- a^2+b^2 )   SQUARE SWAP SQUARE + ;

3 4 SUM-OF-SQUARES .   ( prints 25 )
5 CUBE .                ( prints 125 )
```

### The Compilation Process

When Forth sees `:`, it:

1. Reads the next word (the name of your new definition)
2. Creates a dictionary entry for it
3. Enters **compile mode**

In compile mode, instead of executing words, Forth compiles their addresses into
the new definition. When it sees `;`, it compiles an exit and returns to
**interpret mode**.

Some words are **immediate** — they execute even during compilation. Control
structures like `IF`, `THEN`, `DO`, and `LOOP` are immediate words that compile
branch instructions.

### IMMEDIATE and [COMPILE]

After defining a word, you can mark it as immediate:

```forth
: MY-WORD   ... ; IMMEDIATE
```

To force compilation of an immediate word (instead of executing it), use
`[COMPILE]`:

```forth
: MY-THEN   [COMPILE] THEN ; IMMEDIATE
```

### RECURSE

A word cannot refer to itself by name during its own definition (the name is
hidden until `;` completes the definition). Use `RECURSE` for recursion:

```forth
: FACTORIAL   ( n -- n! )
   DUP 1 > IF
      DUP 1 - RECURSE *
   THEN ;

6 FACTORIAL .   ( prints 720 )
```

---

## 7. Stack Manipulation

Mastering the stack is the key skill in Forth. These words rearrange items on
the stack without performing arithmetic.

### Essential Stack Words

| Word | Stack effect | Description |
|------|-------------|-------------|
| `DUP` | `( n -- n n )` | Duplicate top |
| `DROP` | `( n -- )` | Discard top |
| `SWAP` | `( a b -- b a )` | Exchange top two |
| `OVER` | `( a b -- a b a )` | Copy second to top |
| `ROT` | `( a b c -- b c a )` | Rotate third to top |
| `-DUP` | `( n -- n n ) or ( 0 -- 0 )` | Duplicate only if non-zero |
| `DEPTH` | `( -- n )` | Number of items on stack |
| `.S` | `( -- )` | Display entire stack (non-destructive) |

### Double-Width Stack Words

| Word | Stack effect | Description |
|------|-------------|-------------|
| `2DUP` | `( a b -- a b a b )` | Duplicate top pair |
| `2DROP` | `( a b -- )` | Discard top pair |
| `2SWAP` | `( a b c d -- c d a b )` | Exchange top two pairs |

### Thinking in Stack Terms

The hardest part of learning Forth is managing the stack mentally. Here are
some tips:

1. **Keep the stack shallow.** If you need more than 3-4 items, use variables.
2. **Document stack effects.** Write `( before -- after )` for every word.
3. **Use `DUP` before consuming.** If you need a value more than once, duplicate it first.
4. **Use `.S` for debugging.** It shows the stack without changing it.

### Example: Temperature Conversion

```forth
: F>C   ( fahrenheit -- celsius )
   32 - 5 * 9 / ;

: C>F   ( celsius -- fahrenheit )
   9 * 5 / 32 + ;

212 F>C .    ( prints 100 )
100 C>F .    ( prints 212 )
```

---

## 8. Conditionals

### IF ... THEN

```forth
: SIGN-TEST   ( n -- )
   0< IF
      ." negative"
   THEN ;

-5 SIGN-TEST     ( prints "negative" )
 5 SIGN-TEST     ( prints nothing )
```

`IF` consumes a flag from the stack. If the flag is non-zero (true), the code
between `IF` and `THEN` executes. If zero (false), execution skips to after `THEN`.

### IF ... ELSE ... THEN

```forth
: SIGN   ( n -- )
   0< IF
      ." negative"
   ELSE
      ." non-negative"
   THEN ;
```

### Nested Conditionals

```forth
: CLASSIFY   ( n -- )
   DUP 0< IF
      DROP ." negative"
   ELSE
      DUP 0= IF
         DROP ." zero"
      ELSE
         . ." is positive"
      THEN
   THEN ;
```

### Boolean Combinations

Since true is -1 (all bits set) and false is 0, you can combine conditions
with `AND` and `OR`:

```forth
: IN-RANGE?   ( n lo hi -- flag )
   ROT DUP ROT          ( lo n n hi )
   > NOT SWAP ROT       ( n>=hi? lo n )
   < NOT AND ;           ( lo<=n AND n<=hi )
```

---

## 9. Loops

### Counted Loops: DO ... LOOP

```forth
10 0 DO
   I .
LOOP
```

Prints: `0 1 2 3 4 5 6 7 8 9`

`DO` takes a limit and start from the stack. `I` pushes the current loop index.
`LOOP` increments the index by 1 and loops back if index < limit.

### +LOOP (Variable Increment)

```forth
50 0 DO
   I .
5 +LOOP
```

Prints: `0 5 10 15 20 25 30 35 40 45`

### Nested Loops

Use `J` to access the outer loop's index:

```forth
3 0 DO
   3 0 DO
      I J * .
   LOOP
   CR
LOOP
```

Prints a multiplication table fragment.

### Indefinite Loops: BEGIN ... UNTIL

```forth
: COUNTDOWN   ( n -- )
   BEGIN
      DUP .
      1 -
      DUP 0=
   UNTIL DROP ;

5 COUNTDOWN      ( prints "5 4 3 2 1" )
```

`UNTIL` pops a flag. If true, the loop exits. If false, it jumps back to `BEGIN`.

### BEGIN ... WHILE ... REPEAT

```forth
: COUNT-DOWN   ( n -- )
   BEGIN
      DUP 0>
   WHILE
      DUP . 1 -
   REPEAT DROP ;
```

`WHILE` tests the condition at the top of the loop. If false, execution jumps
past `REPEAT`. This means the loop body may execute zero times.

### BEGIN ... AGAIN (Infinite Loop)

```forth
: FOREVER   BEGIN ." Hello " AGAIN ;
```

Use with caution — the only way to exit is an error or reset.

### LEAVE

`LEAVE` exits a DO loop immediately:

```forth
100 0 DO
   I DUP . CR
   50 = IF LEAVE THEN
LOOP
```

---

## 10. Variables and Constants

### Constants

```forth
7 CONSTANT DAYS-PER-WEEK
365 CONSTANT DAYS-PER-YEAR

DAYS-PER-WEEK .      ( prints 7 )
```

A constant simply pushes its value when executed.

### Built-in Constants

| Word | Value | Description |
|------|-------|-------------|
| `0` | 0 | Zero |
| `1` | 1 | One |
| `2` | 2 | Two |
| `3` | 3 | Three |
| `BL` | 32 | Space character (blank) |
| `TRUE` | -1 | Boolean true |
| `FALSE` | 0 | Boolean false |

### Variables

```forth
VARIABLE SCORE
VARIABLE LIVES
```

A variable reserves 2 bytes of memory. To use it:

| Operation | Code | Description |
|-----------|------|-------------|
| Read | `SCORE @` | Fetch value (pushes it onto stack) |
| Write | `100 SCORE !` | Store 100 into SCORE |
| Add to | `10 SCORE +!` | Add 10 to current value |

### Example: Simple Counter

```forth
VARIABLE COUNT

: RESET   0 COUNT ! ;
: BUMP    1 COUNT +! ;
: SHOW    COUNT @ . ;

RESET
BUMP BUMP BUMP
SHOW              ( prints 3 )
```

---

## 11. Memory Access

Forth gives you direct access to the TS2068's entire 64K address space.

### Word (16-bit) Access

| Word | Stack | Description |
|------|-------|-------------|
| `@` | `( addr -- n )` | Fetch 16-bit value from addr |
| `!` | `( n addr -- )` | Store 16-bit value to addr |
| `+!` | `( n addr -- )` | Add n to 16-bit value at addr |
| `2@` | `( addr -- d )` | Fetch 32-bit double from addr |
| `2!` | `( d addr -- )` | Store 32-bit double to addr |

### Byte Access

| Word | Stack | Description |
|------|-------|-------------|
| `C@` | `( addr -- c )` | Fetch byte from addr |
| `C!` | `( c addr -- )` | Store byte to addr |

### Block Operations

| Word | Stack | Description |
|------|-------|-------------|
| `CMOVE` | `( src dest n -- )` | Copy n bytes from src to dest |
| `FILL` | `( addr n c -- )` | Fill n bytes at addr with c |
| `ERASE` | `( addr n -- )` | Fill n bytes with zero |
| `MOVE` | `( src dest n -- )` | Copy n bytes (handles overlap) |

### Memory Dump

```forth
32768 64 DUMP     ( hex dump of 64 bytes starting at $8000 )
```

### Example: Reading the Keyboard

The TS2068 keyboard state is accessible through port $FE:

```forth
: KEY?   ( -- flag )   KEY ?TERMINAL ;
```

---

## 12. Strings and Text

### Inline Strings

```forth
." Hello, world!"
```

`."` prints the text between `."` and `"`. It works both at the command line and
inside definitions.

```forth
: GREET   ." Welcome to Forth!" CR ;
```

### Counted Strings

A **counted string** is a byte containing the length, followed by the characters.
Many Forth words work with `( addr len )` pairs:

| Word | Stack | Description |
|------|-------|-------------|
| `TYPE` | `( addr n -- )` | Print n characters from addr |
| `COUNT` | `( addr -- addr+1 n )` | Convert counted string to addr+len |
| `EXPECT` | `( addr n -- )` | Read up to n chars from keyboard into addr |
| `-TRAILING` | `( addr n -- addr n' )` | Remove trailing spaces |

### Comments

```forth
( This is a comment — everything between parentheses is ignored )

: HYPOTENUSE   ( a b -- c )
   ( Compute sqrt of a^2 + b^2 using integer math )
   SWAP DUP * SWAP DUP * + ;
```

The word `(` is immediate — it scans forward to `)` and ignores everything between.
Note the space after `(` — it is a word, not syntax.

---

## 13. The Dictionary

Forth's dictionary is a linked list of word definitions. You can inspect it.

### Browsing

| Word | Description |
|------|-------------|
| `WORDS` or `VLIST` | List all defined words |
| `FORGET name` | Remove `name` and everything defined after it |

### Dictionary Internals

Each entry has:

```
[LFA]  Link Field — points to previous entry
[NFA]  Name Field — count byte + name characters
[CFA]  Code Field — pointer to execution handler
[PFA]  Parameter Field — data or compiled thread
```

| Word | Stack | Description |
|------|-------|-------------|
| `'` (tick) | `( -- cfa )` | Find next word, return its CFA |
| `EXECUTE` | `( cfa -- )` | Execute the word at CFA |
| `LATEST` | `( -- nfa )` | NFA of most recently defined word |
| `HERE` | `( -- addr )` | Next available dictionary address |
| `ALLOT` | `( n -- )` | Reserve n bytes in dictionary |
| `,` | `( n -- )` | Compile n into dictionary |
| `C,` | `( c -- )` | Compile byte into dictionary |
| `LFA` | `( nfa -- lfa )` | Convert NFA to LFA |
| `CFA` | `( nfa -- cfa )` | Convert NFA to CFA |
| `NFA` | `( lfa -- nfa )` | Convert LFA to NFA |
| `PFA` | `( cfa -- pfa )` | Convert CFA to PFA |

### Example: Execute a Word by Name

```forth
' SQUARE EXECUTE     ( same as typing SQUARE )
```

---

## 14. Number Bases

Forth can work in any number base from 2 to 36.

| Word | Description |
|------|-------------|
| `HEX` | Switch to base 16 (hexadecimal) |
| `DECIMAL` | Switch to base 10 |
| `BASE` | USER variable holding current base |

```forth
HEX
FF .         ( prints 255... wait, it prints FF in hex )
DECIMAL
255 .        ( prints 255 )
```

You can set any base:

```forth
2 BASE !     ( binary mode )
1010 .       ( prints 10 in decimal — the binary value 1010 )
DECIMAL
```

---

## 15. The Return Stack

Forth has a second stack called the **return stack**, normally used internally to
hold return addresses for word calls. You can temporarily store values there:

| Word | Stack | Description |
|------|-------|-------------|
| `>R` | `( n -- ) R:( -- n )` | Move top of data stack to return stack |
| `R>` | `( -- n ) R:( n -- )` | Move top of return stack to data stack |
| `R` or `I` | `( -- n ) R:( n -- n )` | Copy top of return stack (don't remove) |

### Rules for the Return Stack

1. Always balance `>R` and `R>` within a single definition.
2. Never leave values on the return stack when a word returns.
3. The return stack is used by `DO`...`LOOP` — be careful inside loops.

### Example: Swapping with the Return Stack

```forth
: ROT   ( a b c -- b c a )
   >R SWAP R> SWAP ;
```

---

## 16. Defining Words with DOES>

`DOES>` lets you create **defining words** — words that create other words with
custom runtime behavior.

### Example: ARRAY

```forth
: ARRAY   ( n -- )
   CREATE 2 * ALLOT
   DOES>  ( index -- addr )
      SWAP 2 * + ;

10 ARRAY SCORES          ( create a 10-element array )
42 3 SCORES !            ( store 42 at index 3 )
3 SCORES @ .             ( prints 42 )
```

How it works:

- `CREATE` builds a new dictionary entry (named `SCORES`)
- `2 * ALLOT` reserves space for 10 cells (20 bytes)
- `DOES>` defines what happens when `SCORES` is executed:
  it takes an index, multiplies by 2, and adds to the base address

---

## 17. Block Editor

Forth traditionally stores source code in **blocks** (also called **screens**).
Each block is 1024 bytes — 16 lines of 64 characters.

### Viewing and Editing Blocks

| Word | Stack | Description |
|------|-------|-------------|
| `LIST` | `( blk -- )` | Display block contents |
| `L` | `( -- )` | List current block (SCR) |
| `CLEAR` | `( blk -- )` | Blank a block |
| `T` | `( line -- )` | Display one line of current block |
| `P` | `( line -- )` | Replace line with text from input |
| `I` | `( line -- )` | Insert blank line (shift others down) |
| `D` | `( line -- )` | Delete line (shift others up) |

### Example Editing Session

```forth
1 CLEAR              ( blank block 1 )
1 LIST               ( show it — all blank )
0 P : SQUARE DUP * ;
1 P : CUBE DUP SQUARE * ;
2 P : TEST 5 CUBE . ;
1 LIST               ( verify your code )
1 LOAD               ( compile and run it )
TEST                  ( prints 125 )
```

### Loading Blocks

| Word | Description |
|------|-------------|
| `LOAD` | `( blk -- )` Interpret a block as Forth source |
| `-->` | Continue interpretation on the next block |

---

## 18. TS2068 Graphics and Sound

### Screen Control

| Word | Stack | Description |
|------|-------|-------------|
| `CLS` | `( -- )` | Clear screen |
| `AT` | `( row col -- )` | Position cursor (0-23 rows, 0-31 cols) |
| `EMIT` | `( c -- )` | Print character |
| `CR` | `( -- )` | Carriage return |

### Colours

| Word | Stack | Description |
|------|-------|-------------|
| `INK` | `( n -- )` | Set ink colour (0-7) |
| `PAPER` | `( n -- )` | Set paper colour (0-7) |
| `BRIGHT` | `( n -- )` | Set bright (0 or 1) |
| `FLASH` | `( n -- )` | Set flash (0 or 1) |
| `BORDER` | `( n -- )` | Set border colour (0-7) |

Colours: 0=black, 1=blue, 2=red, 3=magenta, 4=green, 5=cyan, 6=yellow, 7=white.

### Graphics

| Word | Stack | Description |
|------|-------|-------------|
| `PLOT` | `( x y -- )` | Plot pixel at x (0-255), y (0-175) |
| `DRAW` | `( dx dy -- )` | Draw relative line from last PLOT |

### Sound

| Word | Stack | Description |
|------|-------|-------------|
| `BEEP` | `( dur pitch -- )` | Play a tone |
| `MS` | `( n -- )` | Delay n milliseconds |

### Port I/O

| Word | Stack | Description |
|------|-------|-------------|
| `P@` | `( port -- byte )` | Read from I/O port |
| `P!` | `( byte port -- )` | Write to I/O port |

### Example: Drawing a Box

```forth
: BOX   ( x y w h -- )
   OVER 0 DO
      2DUP I + PLOT
   LOOP
   SWAP 0 DO
      2DUP SWAP I + SWAP PLOT
   LOOP
   2DROP ;
```

---

## 19. Floating-Point

TS2068 fig-FORTH interfaces with the Spectrum ROM's floating-point calculator.
Floating-point numbers live on a **separate stack** from the integer stack.

### Moving Values Between Stacks

| Word | Integer Stack | FP Stack | Description |
|------|--------------|----------|-------------|
| `INT>F` | `( n -- )` | `( -- r )` | Integer to float |
| `F>INT` | `( -- n )` | `( r -- )` | Float to integer (truncates) |

### Arithmetic

| Word | FP Stack | Description |
|------|----------|-------------|
| `F+` | `( r1 r2 -- r1+r2 )` | Add |
| `F-` | `( r1 r2 -- r1-r2 )` | Subtract |
| `F*` | `( r1 r2 -- r1*r2 )` | Multiply |
| `F/` | `( r1 r2 -- r1/r2 )` | Divide |
| `FNEGATE` | `( r -- -r )` | Negate |
| `FABS` | `( r -- |r| )` | Absolute value |
| `FSQRT` | `( r -- sqrt(r) )` | Square root |

### Transcendental Functions

| Word | FP Stack | Description |
|------|----------|-------------|
| `FSIN` | `( r -- sin(r) )` | Sine (radians) |
| `FCOS` | `( r -- cos(r) )` | Cosine |
| `FTAN` | `( r -- tan(r) )` | Tangent |
| `FLN` | `( r -- ln(r) )` | Natural logarithm |
| `FEXP` | `( r -- e^r )` | Exponential |

### FP Stack Manipulation

| Word | FP Stack | Description |
|------|----------|-------------|
| `FDUP` | `( r -- r r )` | Duplicate |
| `FDROP` | `( r -- )` | Discard |
| `FSWAP` | `( r1 r2 -- r2 r1 )` | Exchange |
| `F.` | `( r -- )` | Print float |

### Example: Hypotenuse

```forth
: FHYPOT   ( -- ) ( F: a b -- c )
   FDUP F* FSWAP FDUP F* F+ FSQRT ;

3 INT>F 4 INT>F FHYPOT F.    ( prints 5 )
```

---

## 20. Tape I/O

### Saving and Loading Block Buffers

| Word | Description |
|------|-------------|
| `SAVE-BUFFERS` | Save all block buffers to tape |
| `LOAD-BUFFERS` | Load block buffers from tape |

### Raw Memory Tape I/O

| Word | Stack | Description |
|------|-------|-------------|
| `TSAVE` | `( addr len blk -- )` | Save memory block to tape |
| `TLOAD` | `( addr len -- )` | Load memory block from tape |

### Typical Workflow

1. Write your program into blocks using the editor
2. `SAVE-BUFFERS` to save your work to tape
3. Later, `LOAD-BUFFERS` to restore your blocks
4. `1 LOAD` to compile your program

---

## 21. Error Handling

### Error Messages

| Message | Meaning |
|---------|---------|
| `?` | Word not found and not a valid number |
| `COMPILE STACK ERROR` | Unbalanced control structure in definition |
| `NOT COMPILING` | Used a compile-only word outside a definition |
| `NOT INTERPRETING` | Used an interpret-only word inside a definition |
| `STRUCTURE MISMATCH` | Control structure pairing error |
| `PROTECTED` | Attempted to FORGET a protected word |

### System Words

| Word | Description |
|------|-------------|
| `ABORT` | Clear stacks, return to interpreter |
| `QUIT` | Return to interpreter (without clearing stack) |
| `WARM` | Warm restart |
| `COLD` | Full cold restart (re-initializes everything) |
| `BYE` | Return to BASIC |

---

## 22. Programming Techniques

### Factoring

The most important Forth technique is **factoring** — breaking problems into
small words. Compare:

Bad (one long definition):
```forth
: BAD-EXAMPLE
   0 DO
      DUP I MOD 0= IF
         I .
      THEN
   LOOP DROP ;
```

Good (factored):
```forth
: DIVISOR?   ( n i -- n flag )   OVER SWAP MOD 0= ;
: SHOW-IF-DIVISOR   ( n i -- n )   2DUP DIVISOR? IF . ELSE DROP THEN ;
: FACTORS   ( n -- )   DUP 1+ 1 DO I SHOW-IF-DIVISOR LOOP DROP ;
```

### State Variables vs. Stack

When the stack gets too deep (more than 3-4 items), consider using a variable:

```forth
VARIABLE TEMP
: COMPLEX-OP   ( a b c -- result )
   TEMP !           ( save c )
   +                ( a+b )
   TEMP @ * ;       ( (a+b)*c )
```

### Lookup Tables

```forth
CREATE POWERS-OF-2
   1 , 2 , 4 , 8 , 16 , 32 , 64 , 128 ,
   256 , 512 , 1024 , 2048 , 4096 , 8192 , 16384 ,

: 2^   ( n -- 2^n )   2 * POWERS-OF-2 + @ ;

10 2^ .     ( prints 1024 )
```

### Vectored Execution

Use `'` (tick) and `EXECUTE` for indirect calls:

```forth
: APPLY   ( n cfa -- result )   SWAP OVER EXECUTE ;
5 ' SQUARE APPLY .    ( prints 25 )
```

---

## 23. Example Programs

### Fibonacci Numbers

```forth
: FIB   ( n -- fib )
   DUP 2 < IF DROP 1
   ELSE
      DUP  1 - RECURSE
      SWAP 2 - RECURSE +
   THEN ;

10 0 DO I FIB . LOOP    ( prints: 1 1 2 3 5 8 13 21 34 55 )
```

### Prime Number Test

```forth
: PRIME?   ( n -- flag )
   DUP 2 < IF DROP 0 EXIT THEN
   DUP 2 = IF DROP -1 EXIT THEN
   DUP 2 /MOD DROP 0= IF DROP 0 EXIT THEN
   3
   BEGIN
      2DUP DUP * >=
   WHILE
      2DUP MOD 0= IF 2DROP 0 EXIT THEN
      2 +
   REPEAT
   DROP -1 ;

: PRIMES   ( n -- )
   2 DO I PRIME? IF I . THEN LOOP ;

100 PRIMES    ( prints all primes below 100 )
```

### Simple Number Guessing Game

```forth
VARIABLE SECRET
VARIABLE GUESSES

: NEW-GAME
   ( Use FRAMES counter as pseudo-random seed )
   23672 @ 100 MOD 1+    ( random 1-100 )
   SECRET !
   0 GUESSES !
   CR ." I'm thinking of a number 1-100." CR ;

: CHECK   ( n -- )
   1 GUESSES +!
   DUP SECRET @ = IF
      DROP ." Correct in " GUESSES @ . ." guesses!" CR
   ELSE
      SECRET @ < IF ." Too low" ELSE ." Too high" THEN CR
   THEN ;

: GUESS   ( n -- )   CHECK ;
```

### Star Pattern

```forth
: STARS   ( n -- )   0 DO 42 EMIT LOOP ;
: PYRAMID   ( n -- )
   DUP 0 DO
      DUP I - SPACES
      I 2 * 1 + STARS
      CR
   LOOP DROP ;

10 PYRAMID
```

### Memory Dump Utility

The built-in `DUMP` word provides a hex memory dump:

```forth
32768 128 DUMP   ( dump 128 bytes from address $8000 )
```

---

## 24. Complete Word Reference

Words are grouped by category. Stack notation: `( before -- after )`.
Words marked **(I)** are IMMEDIATE (execute during compilation).

### Stack Operations

| Word | Stack | Description |
|------|-------|-------------|
| `DUP` | `( n -- n n )` | Duplicate top |
| `DROP` | `( n -- )` | Discard top |
| `SWAP` | `( a b -- b a )` | Exchange top two |
| `OVER` | `( a b -- a b a )` | Copy second to top |
| `ROT` | `( a b c -- b c a )` | Rotate third to top |
| `-DUP` | `( n -- 0 \| n n )` | Duplicate if non-zero |
| `2DUP` | `( a b -- a b a b )` | Duplicate pair |
| `2DROP` | `( a b -- )` | Drop pair |
| `2SWAP` | `( a b c d -- c d a b )` | Swap pairs |
| `>R` | `( n -- ) R:( -- n )` | Move to return stack |
| `R>` | `( -- n ) R:( n -- )` | Move from return stack |
| `R` | `( -- n )` | Copy return stack top |
| `I` | `( -- n )` | Loop index (same as R) |
| `J` | `( -- n )` | Outer loop index |
| `SP@` | `( -- addr )` | Parameter stack pointer |
| `SP!` | `( addr -- )` | Set parameter stack pointer |
| `RP@` | `( -- addr )` | Return stack pointer |
| `RP!` | `( addr -- )` | Set return stack pointer |
| `DEPTH` | `( -- n )` | Stack depth |
| `.S` | `( -- )` | Display stack (non-destructive) |

### Arithmetic

| Word | Stack | Description |
|------|-------|-------------|
| `+` | `( a b -- a+b )` | Add |
| `-` | `( a b -- a-b )` | Subtract |
| `*` | `( a b -- a*b )` | Multiply |
| `/` | `( a b -- a/b )` | Divide |
| `MOD` | `( a b -- rem )` | Modulus |
| `/MOD` | `( a b -- rem quot )` | Divide with remainder |
| `*/` | `( a b c -- a*b/c )` | Scale (32-bit intermediate) |
| `*/MOD` | `( a b c -- rem a*b/c )` | Scale with remainder |
| `MINUS` | `( n -- -n )` | Negate |
| `NEGATE` | `( n -- -n )` | Negate (alias) |
| `ABS` | `( n -- \|n\| )` | Absolute value |
| `MIN` | `( a b -- min )` | Minimum |
| `MAX` | `( a b -- max )` | Maximum |
| `1+` | `( n -- n+1 )` | Increment |
| `2+` | `( n -- n+2 )` | Add 2 |

### Double-Length Arithmetic

| Word | Stack | Description |
|------|-------|-------------|
| `D+` | `( d1 d2 -- d3 )` | Double add |
| `DMINUS` | `( d -- -d )` | Double negate |
| `DABS` | `( d -- \|d\| )` | Double absolute value |
| `S->D` | `( n -- d )` | Sign-extend to double |
| `U*` | `( u1 u2 -- ud )` | Unsigned multiply (32-bit result) |
| `U/` | `( ud u -- uq ur )` | Unsigned divide |
| `M*` | `( n1 n2 -- d )` | Signed multiply |
| `M/` | `( d n -- quot )` | Signed divide |
| `+-` | `( n1 n2 -- n3 )` | Apply sign of n2 to n1 |
| `D+-` | `( d n -- d' )` | Apply sign of n to d |

### Comparison

| Word | Stack | Description |
|------|-------|-------------|
| `=` | `( a b -- flag )` | Equal |
| `<` | `( a b -- flag )` | Less than (signed) |
| `>` | `( a b -- flag )` | Greater than (signed) |
| `U<` | `( a b -- flag )` | Less than (unsigned) |
| `0=` | `( n -- flag )` | Equal to zero |
| `0<` | `( n -- flag )` | Negative |

### Logic

| Word | Stack | Description |
|------|-------|-------------|
| `AND` | `( a b -- a&b )` | Bitwise AND |
| `OR` | `( a b -- a\|b )` | Bitwise OR |
| `XOR` | `( a b -- a^b )` | Bitwise XOR |
| `NOT` | `( a -- ~a )` | Bitwise complement |

### Memory

| Word | Stack | Description |
|------|-------|-------------|
| `@` | `( addr -- n )` | Fetch 16-bit |
| `!` | `( n addr -- )` | Store 16-bit |
| `C@` | `( addr -- c )` | Fetch byte |
| `C!` | `( c addr -- )` | Store byte |
| `2@` | `( addr -- d )` | Fetch 32-bit |
| `2!` | `( d addr -- )` | Store 32-bit |
| `+!` | `( n addr -- )` | Add to memory cell |
| `TOGGLE` | `( addr b -- )` | XOR byte at addr with b |
| `CMOVE` | `( src dst n -- )` | Copy n bytes |
| `MOVE` | `( src dst n -- )` | Copy with overlap handling |
| `FILL` | `( addr n c -- )` | Fill n bytes with c |
| `ERASE` | `( addr n -- )` | Zero n bytes |
| `DUMP` | `( addr n -- )` | Hex dump |

### I/O

| Word | Stack | Description |
|------|-------|-------------|
| `EMIT` | `( c -- )` | Print character |
| `KEY` | `( -- c )` | Wait for keypress |
| `?TERMINAL` | `( -- flag )` | True if key has been pressed |
| `CR` | `( -- )` | Carriage return |
| `SPACE` | `( -- )` | Print space |
| `SPACES` | `( n -- )` | Print n spaces |
| `TYPE` | `( addr n -- )` | Print string |
| `COUNT` | `( addr -- addr+1 n )` | Unpack counted string |
| `EXPECT` | `( addr n -- )` | Read line input |
| `-TRAILING` | `( addr n -- addr n' )` | Remove trailing spaces |
| `."` **(I)** | `( -- )` | Print inline string |
| `.(` **(I)** | `( -- )` | Print to closing `)` |

### Number Output

| Word | Stack | Description |
|------|-------|-------------|
| `.` | `( n -- )` | Print signed number |
| `U.` | `( u -- )` | Print unsigned number |
| `D.` | `( d -- )` | Print signed double |
| `.R` | `( n w -- )` | Print right-justified |
| `<#` | `( -- )` | Begin pictured output |
| `#` | `( d -- d' )` | Extract one digit |
| `#S` | `( d -- 0 0 )` | Extract all digits |
| `#>` | `( d -- addr len )` | End pictured output |
| `HOLD` | `( c -- )` | Insert char in output |
| `SIGN` | `( n -- )` | Add sign if negative |

### Dictionary and Compiler

| Word | Stack | Description |
|------|-------|-------------|
| `:` | `( -- )` | Begin colon definition |
| `;` **(I)** | `( -- )` | End colon definition |
| `CREATE` | `( -- )` | Create dictionary entry |
| `VARIABLE` | `( -- )` | Create variable |
| `CONSTANT` | `( n -- )` | Create constant |
| `USER` | `( n -- )` | Create USER variable |
| `DOES>` **(I)** | `( -- )` | Define runtime of created word |
| `IMMEDIATE` | `( -- )` | Mark last word as immediate |
| `[COMPILE]` **(I)** | `( -- )` | Compile next word even if immediate |
| `RECURSE` **(I)** | `( -- )` | Compile call to current definition |
| `'` | `( -- cfa )` | Find word, return CFA |
| `[']` **(I)** | `( -- )` | Compile CFA as literal |
| `EXECUTE` | `( cfa -- )` | Execute word at CFA |
| `HERE` | `( -- addr )` | Dictionary pointer |
| `ALLOT` | `( n -- )` | Reserve n bytes |
| `,` | `( n -- )` | Compile 16-bit value |
| `C,` | `( c -- )` | Compile byte |
| `COMPILE` | `( -- )` | Compile next CFA from thread |
| `LITERAL` **(I)** | `( n -- )` | Compile n as literal |
| `DLITERAL` **(I)** | `( d -- )` | Compile double as literal |
| `SMUDGE` | `( -- )` | Toggle smudge bit on latest word |
| `LATEST` | `( -- nfa )` | NFA of latest word |
| `TRAVERSE` | `( addr dir -- addr' )` | Walk name field |
| `LFA` | `( nfa -- lfa )` | NFA to LFA |
| `NFA` | `( lfa -- nfa )` | LFA to NFA |
| `CFA` | `( nfa -- cfa )` | NFA to CFA |
| `PFA` | `( cfa -- pfa )` | CFA to PFA |
| `ID.` | `( nfa -- )` | Print word name |
| `WORDS` | `( -- )` | List all words |
| `VLIST` | `( -- )` | List all words (same as WORDS) |
| `FORGET` | `( -- )` | Remove word and all after it |
| `-FIND` | `( -- cfa b tf \| ff )` | Parse and search dictionary |

### Control Flow (all IMMEDIATE)

| Word | Stack | Description |
|------|-------|-------------|
| `IF` | `( flag -- )` | Begin conditional |
| `ELSE` | `( -- )` | Alternate branch |
| `THEN` | `( -- )` | End conditional |
| `ENDIF` | `( -- )` | End conditional (alias) |
| `BEGIN` | `( -- )` | Start indefinite loop |
| `UNTIL` | `( flag -- )` | Loop back if false |
| `WHILE` | `( flag -- )` | Exit loop if false |
| `REPEAT` | `( -- )` | End BEGIN..WHILE loop |
| `AGAIN` | `( -- )` | Unconditional loop back |
| `DO` | `( limit start -- )` | Begin counted loop |
| `LOOP` | `( -- )` | Increment and test loop |
| `+LOOP` | `( n -- )` | Add n and test loop |
| `LEAVE` | `( -- )` | Exit DO loop |

### Compiler State

| Word | Stack | Description |
|------|-------|-------------|
| `STATE` | `( -- addr )` | Compile state (0=interpret) |
| `?COMP` | `( -- )` | Error if not compiling |
| `?EXEC` | `( -- )` | Error if not interpreting |
| `?CSP` | `( -- )` | Check stack balance |
| `!CSP` | `( -- )` | Save stack pointer |
| `?PAIRS` | `( n1 n2 -- )` | Check structure matching |

### Number Bases

| Word | Stack | Description |
|------|-------|-------------|
| `DECIMAL` | `( -- )` | Set base to 10 |
| `HEX` | `( -- )` | Set base to 16 |
| `BASE` | `( -- addr )` | USER variable: current base |

### Block I/O

| Word | Stack | Description |
|------|-------|-------------|
| `BLOCK` | `( n -- addr )` | Get buffer for block n |
| `BUFFER` | `( n -- addr )` | Assign buffer for block n |
| `UPDATE` | `( -- )` | Mark buffer as modified |
| `FLUSH` | `( -- )` | Write modified buffers |
| `LOAD` | `( n -- )` | Interpret block as source |
| `LIST` | `( n -- )` | Display block |
| `-->` | `( -- )` | Continue on next block |
| `EMPTY-BUFFERS` | `( -- )` | Clear all buffers |
| `LINE` | `( n blk -- addr )` | Address of line in block |

### Screen Editor

| Word | Stack | Description |
|------|-------|-------------|
| `L` | `( -- )` | List current screen |
| `T` | `( n -- )` | Type line n |
| `P` | `( n -- )` | Put text into line n |
| `I` | `( n -- )` | Insert blank line at n |
| `D` | `( n -- )` | Delete line n |
| `CLEAR` | `( blk -- )` | Blank entire block |

### TS2068 Hardware

| Word | Stack | Description |
|------|-------|-------------|
| `CLS` | `( -- )` | Clear screen |
| `AT` | `( row col -- )` | Position cursor |
| `PLOT` | `( x y -- )` | Plot pixel |
| `DRAW` | `( dx dy -- )` | Draw relative line |
| `INK` | `( n -- )` | Set ink colour (0-7) |
| `PAPER` | `( n -- )` | Set paper colour (0-7) |
| `BRIGHT` | `( n -- )` | Set bright (0/1) |
| `FLASH` | `( n -- )` | Set flash (0/1) |
| `BORDER` | `( n -- )` | Set border colour (0-7) |
| `BEEP` | `( dur pitch -- )` | Play tone |
| `MS` | `( n -- )` | Delay milliseconds |
| `P@` | `( port -- byte )` | Read I/O port |
| `P!` | `( byte port -- )` | Write I/O port |

### Floating-Point

| Word | Integer Stack | FP Stack | Description |
|------|--------------|----------|-------------|
| `INT>F` | `( n -- )` | `( -- r )` | Integer to float |
| `F>INT` | `( -- n )` | `( r -- )` | Float to integer |
| `F+` | — | `( r1 r2 -- r3 )` | Add |
| `F-` | — | `( r1 r2 -- r3 )` | Subtract |
| `F*` | — | `( r1 r2 -- r3 )` | Multiply |
| `F/` | — | `( r1 r2 -- r3 )` | Divide |
| `FNEGATE` | — | `( r -- -r )` | Negate |
| `FABS` | — | `( r -- \|r\| )` | Absolute value |
| `FSQRT` | — | `( r -- sqrt )` | Square root |
| `FSIN` | — | `( r -- sin )` | Sine |
| `FCOS` | — | `( r -- cos )` | Cosine |
| `FTAN` | — | `( r -- tan )` | Tangent |
| `FLN` | — | `( r -- ln )` | Natural log |
| `FEXP` | — | `( r -- e^r )` | Exponential |
| `FDUP` | — | `( r -- r r )` | Duplicate |
| `FDROP` | — | `( r -- )` | Discard |
| `FSWAP` | — | `( r1 r2 -- r2 r1 )` | Exchange |
| `F.` | — | `( r -- )` | Print |

### Tape I/O

| Word | Stack | Description |
|------|-------|-------------|
| `TSAVE` | `( addr len blk -- )` | Save to tape |
| `TLOAD` | `( addr len -- )` | Load from tape |
| `SAVE-BUFFERS` | `( -- )` | Save all buffers |
| `LOAD-BUFFERS` | `( -- )` | Load all buffers |

### System

| Word | Stack | Description |
|------|-------|-------------|
| `ABORT` | `( -- )` | Clear stacks, restart interpreter |
| `QUIT` | `( -- )` | Restart interpreter (keep stack) |
| `WARM` | `( -- )` | Warm restart |
| `COLD` | `( -- )` | Cold restart |
| `BYE` | `( -- )` | Return to BASIC |
| `INTERPRET` | `( -- )` | Process input buffer |
| `NOOP` | `( -- )` | Do nothing |

### Constants

| Word | Value |
|------|-------|
| `0` | 0 |
| `1` | 1 |
| `2` | 2 |
| `3` | 3 |
| `BL` | 32 (space) |
| `TRUE` | -1 |
| `FALSE` | 0 |
| `B/BUF` | 1024 (bytes per buffer) |
| `B/SCR` | 1 (buffers per screen) |
| `FIRST` | Buffer start address |
| `LIMIT` | Buffer end address |

### USER Variables

These are per-instance system variables accessed with `@` and `!`:

| Word | Description |
|------|-------------|
| `S0` | Initial stack pointer |
| `R0` | Initial return stack pointer |
| `TIB` | Terminal input buffer address |
| `WIDTH` | Maximum name length (31) |
| `WARNING` | Warning mode |
| `FENCE` | FORGET protection address |
| `DP` | Dictionary pointer (same as HERE) |
| `VOC-LINK` | Vocabulary link |
| `BLK` | Current block number (0=terminal) |
| `IN` | Input buffer offset |
| `OUT` | Output column |
| `SCR` | Current screen number |
| `OFFSET` | Block offset |
| `CONTEXT` | Search vocabulary |
| `CURRENT` | Compile vocabulary |
| `STATE` | Compile state |
| `BASE` | Number base |
| `DPL` | Decimal point location |
| `FLD` | Field width |
| `CSP` | Saved stack pointer |
| `R#` | Editor cursor line |
| `HLD` | Pictured output pointer |

---

## Quick Reference Card

### Most-Used Words

```
Stack:    DUP DROP SWAP OVER ROT
Math:     + - * / MOD ABS
Compare:  = < > 0= 0<
Logic:    AND OR NOT
Memory:   @ ! C@ C!
I/O:      . CR EMIT ." TYPE
Define:   : ; VARIABLE CONSTANT
Flow:     IF ELSE THEN
Loops:    DO LOOP BEGIN UNTIL AGAIN
System:   WORDS .S HEX DECIMAL DUMP
```

### Keyboard Quick Reference (TS2068)

The TS2068 keyboard produces lowercase letters. The Forth system automatically
converts to uppercase for word lookup. Special characters use SYMBOL SHIFT (SS):

| Character | Keys | Character | Keys |
|-----------|------|-----------|------|
| `!` | SS + 1 | `"` | SS + P |
| `@` | SS + 2 | `#` | SS + 3 |
| `$` | SS + 4 | `%` | SS + 5 |
| `&` | SS + 6 | `'` | SS + 7 |
| `(` | SS + 8 | `)` | SS + 9 |
| `+` | SS + K | `-` | SS + J |
| `*` | SS + B | `/` | SS + V |
| `.` | SS + M | `,` | SS + N |
| `:` | SS + Z | `;` | SS + O |
| `<` | SS + R | `>` | SS + T |
| `=` | SS + L | `_` | SS + 0 |
| `?` | SS + C | `^` | SS + H |
| DELETE | DELETE key | | |

---

*TS2068 fig-FORTH v0.1 — Public Domain / Open Source*
*Based on the fig-FORTH standard with TS2068 extensions.*

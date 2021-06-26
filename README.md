# Mezz'Estate Neogeo Audio Driver
*ADPCM-B isn't supported as of right now.*

## Deflemask to NeogeoDev Wiki FM parameters
Deflemask | NeogeoDevWiki
----------|--------------
DT        | DT
MUL       | MUL
RS        | KS
A         | AR
D         | DR
S         | SL
D2        | SR
R         | RR

## Z80 memory map
Address space | Description           | Usage
--------------|-----------------------|---------------------------------------------
$0000 ~ $3FFF | Static main code bank | code
$4000 ~ $7FFF | Static main code bank | MLM header and songs
$8000 ~ $BFFF | Switchable bank 3     | songs
$C000 ~ $DFFF | Switchable bank 2     | instruments
$E000 ~ $EFFF | Switchable bank 1     | Other data (macros, ADPCM addresses, etc...)
$F000 ~ $F7FF | Switchable bank 0     | Other data (macros, ADPCM addresses, etc...)
$F800 ~ $FFFF | Work RAM              | Work RAM

## MLM format documentation

**Any address is an offset from the start of the MLM Header ($4000),
not the start of the Z80's address space**

*For example, address $0010 in the MLM code would be treated as $4010 in the code*

### BANK3 - Song data
BANK3 contains the song data. it must begin with this header:

|offsets | description                              | bytes 
|--------|------------------------------------------|-------
|$00     | song 0 bank (Zone3; SOON)                | 1
|$0001   | song 0 offset                            | 2
|...     | ...                                      |
|...     | last song bank (Zone3; SOON)             | 1
|...     | last song offset (maximum of 256* songs) | 2

* Only the first 128 songs can be played as of right now.

each song should start with this header


offsets | description       | bytes
--------|-------------------|------
$0000   | Song count        | 1
$0001   | Channel 0 offset  | 2
...     | ...               |
$001B   | Channel 12 offset | 2
$001D   | Timer A counter   | 2
$001F   | Mode              | 1
$0020   | Zone 2 bank       | 1
$0021   | Zone 1 bank       | 1
$0022   | Zone 0 bank       | 1

Mode should be used to enable or disable deflemask compatibility, it currently does nothing but I'm putting it in the specs just in case.
each channel is an array of events. The driver executes the event, and then waits the amount of time specifies in the event.
Events can be split in two categories, depending on the most significant bit. 

If the most significant bit is 1, then the event is a **note**, if the most significant bit is 0, then the event is a **command**. Both notes and events will be parsed and interpreted differently depending on the kind of channel (ADPCM-A, SSG, FM)

#### Channels
* Channels 0\~5: ADPCM-A channels
* Channels 6\~9: FM channels
* Channels 10\~12: SSG channels

#### Notes
Notes are events that, like the name implies, play a note from the current instrument (defaults to 0).

```
ADPCM-A:
	-TTTTTTT SSSSSSSS (Sample; Timing)

SSG:
	-TTTTTTT NNNNNNNN (Timing; Note*)

FM:
	-TTTTTTT -OOONNNN (Timing; Octave; Note)

* SSG Note = octave*12 + note
```

#### Commands
command do pretty much anything else a song needs. Commands are formatted differently depending on the command itself, and on the kind of channel it's executed on.

##### Command list

###### Command 0: End of event list
**format: `$00`**

this command ends the playback for the current channel

###### Command 1: Note off
**format: `$01 %TTTTTTTT (Timing)`**

###### Command 2: Change instrument
**format: `$02 %IIIIIIII (Instrument; Next event is executed immediately)`**

###### Command 3: Wait ticks (byte)
**format: `$03 %TTTTTTTT (Timing)`**

###### Command 4: Wait ticks (word)
**format: `$04 %TTTTTTTT (Timing LSB) %TTTTTTTT (Timing MSB)`**

###### Command 5: Set channel volume
**format: `$05 %VVVVVVVV (Volume) %TTTTTTTT (Timing)`**

###### Command 6: Set panning
**format: `$06 %LRTTTTTT (Left on; Right on; Timing)`**

*ADPCM-A and FM only*

###### Command 7: Set master volume
**format: `$07 %VVVVVVTT (Volume; Timing MSB) %TTTTTTTT (Timing LSB)`**

*ADPCM-A only*

###### Command 8: Set base time
**format: `$08 %BBBBBBBB (Base Time) %TTTTTTTT (Timing)`**

###### Command 9: Jump to sub-event list
**format $09 %AAAAAAAA (Address LSB) %AAAAAAAA (Address MSB)**

Does NOT allow nesting. Do not use this command in a sub event list.

###### Command 10: Small position jump
**format: `$0A %OOOOOOOO (Offset; next event is executed immediately)`**

Offset = destination addr. - (current event addr. + 1 + current event argc)

###### Command 11: Big position jump
**format: `$0B %AAAAAAAA (Address LSB) %AAAAAAAA (Address MSB)`**

###### Command 12: Portamento slide (Still not implemented)
**format: `$0C %SSSSSSSS (Signed pitch offset per tick) %TTTTTTTT (Timing)`**

###### Command 13: YM2610 Port A write
**format: `$0D %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 14: YM2610 Port B write
**format: `$0E %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 15: Set timer A frequency
**format: `$0F %AAAAAAAA (timer A MSB) %TTTTTTAA (Timing; timer A LSB)`**

###### Command 16\~31: Wait ticks (nibble)
**format: `$1T (Timing)`**

###### Command 32: Return from sub event list
**format: `$20`**

### BANK2, 1 and 0 - instruments and other data
The driver can access up to 256 instruments at a time in BANK2, each instrument
occupies 32 bytes, how those 32 bytes are used depends on the channel type (ADPCM, FM, SSG).
Additionally, some data of the instrument might be stored in BANK1 and BANK0 (SSG macros for example).
The use of BANK1 and BANK0 isn't obligatory, but not using said banks imposes several limitations.

#### ADPCM-A instrument structure

offset | description            | bytes
-------|------------------------|------
$0000  | Pointer to sample list | 2
$0002  | Padding                | 30

#### sample list structure

offset | description                    | bytes
-------|--------------------------------|------
$0000  | Sample 0 start address / 256   | 2
$0002  | Sample 0 end address / 256     | 2
...    | ...                            | ...
$03FC  | Sample 255 start address / 256 | 2
$03FE  | Sample 255 end address / 256   | 2

#### FM instrument structure

offset | description                              | bytes
-------|------------------------------------------|------
$0000  | Feedback (FB) and Algorithm (ALGO)       | 1
$0001  | AM Sense (AMS), and PM Sense (PMS)       | 1
$0002  | OP enable                                | 1
$0003  | FM operator 1 data                       | 7
$000A  | FM operator 2 data                       | 7
$0011  | FM operator 3 data                       | 7
$0018  | FM operator 4 data                       | 7
$001F  | Padding                                  | 1

##### FM operator data

offset | description                              | bytes
-------|------------------------------------------|------
$0002  | Detune (DT) and Multiple (MUL)           | 1
$0003  | Total Level (Volume)                     | 1
$0004  | Key Scale (KS) and Attack Rate (AR)      | 1
$0005  | AM On (AM) and Decay Rate (DR)           | 1
$0006  | Sustain Rate (SR)                        | 1
$0007  | Sustain Level (SL) and Release Rate (RR) | 1
$0008  | Envelope generator                       | 1

Check the neogeodev wiki (or any YM2610 document) to see
how the FM channel/operator data is arranged, they're
arranged in the same way they are in the register. Except for
"AM Sense (AMS), and PM Sense (PMS)", which excludes the panning,
that is set by the song.

#### SSG instrument structure

offset | description                        | bytes
-------|------------------------------------|------
$0000  | Mixing*                            | 1
$0001  | EG Enable                          | 1
$0002  | Volume envelope period fine tune   | 1
$0003  | Volume envelope period coarse tune | 1
$0004  | Volume envelope shape              | 1
$0005  | Pointer to mix macro               | 2
$0007  | Pointer to volume macro            | 2
$0009  | Pointer to arpeggio macro          | 2
$000A  | Padding                            | 21

\* 0: None; 1: Tone; 2: Noise; 3: Tone & Noise; Will be ignored if mix macros are enabled

If any macro pointer is set to $0000, then that macro will be disabled.

#### SSG macro structure

offset | description                        | bytes
-------|------------------------------------|------
$0000  | Macro length - 1                   | 1
$0001  | Macro loop point                   | 1
$0002  | Macro data                         | 1..128/256

There are two kinds of macros, nibble macros and byte macros.
Nibble macros store two values per byte, they're used for mixing, noise tune and volume macros.
Byte macros store one value per byte, they're used for arpeggios.
Nibble macros can be up to 128 bytes big, Byte macros can instead reach 256 bytes.
The length of a macro is the count of how many values it contains.
Values in nibble macros are ordered in such a way that the sequence {0; 1; 2; 3} would be encoded
to {$10; $32}.

## Driver Documentation

### 68K/Z80 user commands

If a byte sent to the Z80 has bit 7 set, then it'll be written to the user command buffer.
Each command is a single word. the LSB is the command, the MSB is the parameter.

#### 68K/Z80 user command list

##### Command 0: NOP
**format: %10000000'10000000**

##### Command 1: Play song
**format: %1SSSSSSS'10000001 (Song index)**

##### Command 2: Stop song
**format: %1-------'10000010**

### Internal IRQ commands
These commands are used internally to safely give commands 
to anything IRQ related (such as the MLM song playback),
each command also has a fixed size of one word, except in
this case all 16 bits are used.

#### Internal IRQ command list

##### Command 0: NOP
**format: %00000000'00000000**

##### Command 1: MLM Play song
**format: %SSSSSSSS'00000001 (Song index)**

##### Command 2: MLM Stop song
**format: %00000000'00000010**

#### Bankswitching
Each song is divided in 8kb blocks. The driver has access to two of these blocks at a time, and they can be switched freely allowing up to 512 KiB of data. The blocks are switched when the other starts playing.
The z80 memory zones used are zone 3 and zone 2. The driver starts playing zone 3 first.


## NOTICE
The z80 code is based on an empty driver made by freem. I've personally found it here (http://www.ajworld.net/neogeodev/beginner/)

## BUGS
* If the pitch slide is set to anything that isn't 0, notes seem to be triggered afterwards
* z80/68k communication doesn't work on real hardware

## TODO
* Implement ADPCM-B
* Update MLM header parsing to allow banking
	1. Implement Zone 3 banking using the bank stored in the MLM header (REMEMBER TO DELAY THIS SOMEHOW)
	2. Implement Zone 2, 1 and 0 banking using the banks stored in the song headers (ALSO ADD A DELAY HERE)

## IDEAS
* Add support for jingles (songs that can play while another song is playing)

* 68k commands that play a sample/note without
having to specify the exact channel (only the kind
of channel). The driver would choose which channel
to play this on (the first unused one, if any)

* If enough events are left there could be versions
of events that set the timing to 0 to save space

* Use a 68k command queue?

## BUILDING

### Dependencies

Install all of these, they need to be all in $PATH.

```
mame, romwak, freem's ADPCMA sample encoder, vasm, make, ngdevkit's gcc toolchain, python (3.7 or newer), vasm
```

## COMMENTS
* Sometimes `<<l` is used in comments, this represents a bitwise left shift that sets the lower bits to 1.
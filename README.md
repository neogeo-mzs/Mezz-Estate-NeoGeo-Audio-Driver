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
$0000 ~ $7FFF | Static main code bank | code
$8000 ~ $BFFF | Switchable bank 3     | songs
$C000 ~ $DFFF | Switchable bank 2     | instruments
$E000 ~ $EFFF | Switchable bank 1     | Other data (macros, ADPCM addresses, etc...)
$F000 ~ $F7FF | Switchable bank 0     | Other data (macros, ADPCM addresses, etc...)
$F800 ~ $FFFF | Work RAM              | Work RAM

## MLM format documentation

### BANK3 - Song data
BANK3 contains the song data. it must begin with this header:

|offsets | description                              | bytes 
|--------|------------------------------------------|-------
|$0000   | song 0 bank (Zone3)                      | 1
|$0001   | song 0 offset                            | 2
|...     | ...                                      |
|...     | last song bank (Zone3)                   | 1
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
$001F   | Zone 2 bank       | 1
$0020   | Zone 1 bank       | 1
$0021   | Zone 0 bank       | 1

each channel is an array of events. The driver executes the event, and then waits the amount of time specifies in the event.
Events can be split in two categories, depending on the most significant bit. 

If the most significant bit is 1, then the event is a **note**, if the most significant bit is 0, then the event is a **command**. Both notes and events will be parsed and interpreted differently depending on the kind of channel (ADPCM-A, SSG, FM)

#### Channels
* Channels 0~5: ADPCM-A channels
* Channels 6~9: FM channels
* Channels 10~12: SSG channels

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

###### Command 9: Deprecated Command

###### Command 10: Small position jump
**format: `$0A %OOOOOOOO (Offset; next event is executed immediately)`**

Offset = destination addr. - (current event addr. + 1 + current event argc)

###### Command 11: Big position jump
**format: `$0B %OOOOOOOO (Offset LSB) %OOOOOOOO (Offset MSB)`**
Offset = destination addr. - (current event addr. + 1 + current event argc)

###### Command 12: Portamento slide (Still not implemented)
**format: `$0C %SSSSSSSS (Signed pitch offset per tick) %TTTTTTTT (Timing)`**

###### Command 13: YM2610 Port A write
**format: `$0D %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 14: YM2610 Port B write
**format: `$0E %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 15: Set timer A frequency
**format: `$0F %AAAAAAAA (timer A MSB) %TTTTTTAA (Timing; timer A LSB)`**

###### Command 16~31: Wait ticks (nibble)
**format: `$1T (Timing)`**

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

TODO

#### SSG instrument structure

offset | description                        | bytes
-------|------------------------------------|------
$0000  | Mixing*                            | 1
$0001  | EG Enable                          | 1
$0002  | Volume envelope period fine tune   | 1
$0003  | Volume envelope period coarse tune | 1
$0004  | Volume envelope shape              | 1
$0005  | Pointer to mix macro               | 2
$0007  | Pointer to arpeggio macro          | 2
$0009  | Pointer to volume macro            | 2
$000A  | Padding                            | 21

\* 0: None; 1: Tone; 2: Noise; 3: Tone & Noise; Will be ignored if mix macros are enabled

If any macro pointer is set to $0000, then that macro won't be enabled.

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

### Internal SSG commands
Used to easily control the 3 SSG channels, they aren't buffered, since
they should only be used in the IRQ interrupt.

##### Command 0: NOP
**format: %00000000'00000000**

##### Command 1: Set note
**format: %CC000001'NNNNNNNN (Channel; Note)**

##### Command 2: Set mixing
**format: %CC000010'------NT (Channel; Noise enable; Tone enable)**

##### Command 3: Set volume
**format: %CC000011'----VVVV (Channel; Volume)**

##### Command 4: Set noise tone
**format: %00000100'---NNNNN (Channel; Noise tone)**

##### Command 5: Set mode
**format: %CC000101'MMMMMMMM (Channel; Mode)**

If mode is 0, the channel won't use the EG for volume. Else, the EG will be used

##### Command 6: Set volume envelope period fine tune
**format: %CC000110'TTTTTTTT (Channel; volume envelope fine Tune)**

##### Command 7: Set volume envelope period coarse tune
**format: %CC000111'TTTTTTTT (Channel; volume envelope coarse Tune)**

##### Command 8: Set volume envelope shape
**format: %CC001000'----SSSS (Channel; volume envelope Shape)**


#### Bankswitching
Each song is divided in 8kb blocks. The driver has access to two of these blocks at a time, and they can be switched freely allowing up to 512 KiB of data. The blocks are switched when the other starts playing.
The z80 memory zones used are zone 3 and zone 2. The driver starts playing zone 3 first.


## NOTICE
The z80 code is based on an empty driver made by freem. I've personally found it here (http://www.ajworld.net/neogeodev/beginner/)

## BUGS
* If the pitch slide is set to anything that isn't 0, notes seem to be triggered afterwards
* z80/68k communication doesn't work on real hardware

## TODO
* Check if SSG playback works correctly
* Check if FM playback works
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
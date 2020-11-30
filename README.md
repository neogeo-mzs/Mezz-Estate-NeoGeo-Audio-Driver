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
--------------|-----------------------|----------------------
$0000 ~ $7FFF | Static main code bank | code
$8000 ~ $BFFF | Switchable bank 3     | songs
$C000 ~ $DFFF | Switchable bank 2     | instruments
$E000 ~ $EFFF | Switchable bank 1     | macros (other data?)
$F000 ~ $F7FF | Switchable bank 0     | ADPCM-A addresses
$F800 ~ $FFFF | Work RAM              | Work RAM

## MLM format documentation

### BANK3
BANK3 contains the song data. it must begin with this header:

|offsets | description                             | bytes 
|--------|-----------------------------------------|-------
|$0000   | song 0 offset                           | 2
|...     | ...                                     | 
|...     | last song offset (maximum of 256 songs) | 2


each song should start with this header


offsets | description       | bytes
--------|-------------------|------ 
$0000   | channel 0 offset  | 2
...     | ...               |
$001A   | channel 12 offset | 2


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
	-TTTTTTS SSSSSSSS (Sample; Timing)

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

###### Command 7: Set master volume
**format: `$07 %VVVVVVTT (Volume; Timing MSB) %TTTTTTTT (Timing LSB)`**

*ADPCM-A only*

###### Command 8: Set base time
**format: `$08 %BBBBBBBB (Base Time) %TTTTTTTT (Timing)`**

###### Command 9: Set timer B frequency (Currently disabled)
**format: `$09 %BBBBBBBB (timer B) %TTTTTTTT (Timing)`**
*This also enables timer b and disables timer a*

###### Command 10: Small position jump
**format: `$0A %OOOOOOOO (Offset; next event is executed immediately)`**

Offset = destination addr. - (current event addr. + 1 + current event argc)

###### Command 11: Big position jump
**format: `$0B %OOOOOOOO (Offset LSB) %OOOOOOOO (Offset MSB)`**

###### Command 12: Portamento slide (Still not implemented)
**format: `$0C %SSSSSSSS (Signed pitch offset per tick) %TTTTTTTT (Timing)`**

###### Command 13: YM2610 Port A write
**format: `$0D %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 14: YM2610 Port B write
**format: `$0E %AAAAAAAA (Address) %DDDDDDDD (Data; next event is executed immediately)`**

###### Command 15: Set timer A frequency
**format: `$0F %AAAAAAAA (timer A LSB) %TTTTTTAA (Timing; timer A MSB)`**
*This also enables timer a and disables timer b*

Offset = destination addr. - (current event addr. + 1 + current event argc)

## NOTICE
The z80 code is based on an empty driver made by freem. I've personally found it here (http://www.ajworld.net/neogeodev/beginner/)

## BUGS
* If the pitch slide is set to anything that isn't 0, notes seem to be triggered afterwards
* z80/68k communication doesn't work on real hardware

## TODO
* Add timer a support
* sfx priority
* bgm fade in/out
* pitch slide command

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
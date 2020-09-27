# THIS IS A WIP, DO NOT USE THIS IN YOUR PRODUCTION CODE BECAUSE SHIT WILL FUCK UP!

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
**format: `$04 %TTTTTTTT %TTTTTTTT (Timing; LSB first MSB after, this will always be the case)`**

###### Command 5: Set channel volume
**format: `$05 %VVVVVVVV %TTTTTTTT (Volume; Timing)`**

###### Command 6: Set master volume
**format: `$06 %VVVVVVTT %TTTTTTTT (Volume; Timing)`**
*ADPCM-A only*

###### Command 7: Set panning
**format: `$07 %LRTTTTTT (Left on; Right on; Timing)**`

## CONTROLS
* A: Play a jingle using ADPCM-A
* B: Play a jingle using SSG 
* C: Play a jingle using FM

## NOTICE
The z80 code is based on an empty driver made by freem. I've personally found it here (http://www.ajworld.net/neogeodev/beginner/)

## BUGS
* Sending lots of play song signals in a short amount of time (by mashing the A, B and C buttons) softlocks the 68k program. (the z80 is reset or does it also softlock?)

## TODO
* Implement master volume event command (ADPCM-A only)

## IDEAS
* If enough events are left there could be versions
of events that set the timing to 0 to save space
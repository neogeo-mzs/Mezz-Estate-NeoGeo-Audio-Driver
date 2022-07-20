# Mezz'Estate Neogeo Audio Driver

Audio driver for the NeoGeo MVS and AES made in assembly.<br/>
Check [the wiki](https://github.com/stereomimi/Mezz-Estate-NeoGeo-Audio-Driver/wiki) for further information

## Z80 memory map
Address space | Description           | Usage
--------------|-----------------------|--------------------------
$0000 ~ $5FFF | Static main code bank | Code
$6000 ~ $7FFF | Static main code bank | MLM header and song data
$8000 ~ $F7FF | Switchable banks      | Song data
$F800 ~ $FFFF | Work RAM              | Work RAM

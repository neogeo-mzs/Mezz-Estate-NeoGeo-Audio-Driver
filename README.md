# Mezz'Estate Neogeo Audio Driver

Audio driver for the NeoGeo MVS and AES made in assembly.<br/>
Check [the wiki](https://github.com/stereomimi/Mezz-Estate-NeoGeo-Audio-Driver/wiki) for further information

## Compilation dependencies
* This specific [ZASM fork](https://github.com/stereomimi/zasm) (You'll have to compile it yourself, there's no actual executables)
* [RomWak](https://github.com/freem/romwak)
* Python 3.9.7+ (Might work with other versions higher than 3.0.0, not tested)
* [adpcma](https://github.com/freem/adpcma) (Just for converting the test's program's samples)
* [ngdevkit](https://github.com/dciabrin/ngdevkit) (Just for compiling the test software)
* Mame (Can be any emulator, but this repo has neat stuff for Mame SDL)
* [NeoSdConv](https://github.com/city41/neosdconv) (Just for exporting to TerraOnion's flashcart)

## Z80 memory map
Address space | Description           | Usage
--------------|-----------------------|--------------------------
$0000 ~ $5FFF | Static main code bank | Code
$6000 ~ $7FFF | Static main code bank | MLM header and song data
$8000 ~ $F7FF | Switchable banks      | Song data
$F800 ~ $FFFF | Work RAM              | Work RAM

# Mezz'Estate Neogeo Audio Driver
Check the wiki for most information!

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
--------------|-----------------------|--------------------------
$0000 ~ $5FFF | Static main code bank | Code
$6000 ~ $7FFF | Static main code bank | MLM header and song data
$8000 ~ $F7FF | Switchable banks      | Song data
$F800 ~ $FFFF | Work RAM              | Work RAM

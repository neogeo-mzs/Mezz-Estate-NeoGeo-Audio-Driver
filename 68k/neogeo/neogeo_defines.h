typedef unsigned char  u8;
typedef unsigned short u16;
typedef unsigned int   u32;
typedef signed char    s8;
typedef signed short   s16;
typedef signed int     s32;

typedef volatile unsigned char  vu8;
typedef volatile unsigned short vu16;
typedef volatile unsigned int   vu32;
typedef volatile signed char    vs8;
typedef volatile signed short   vs16;
typedef volatile signed int     vs32;

// Hard DIPs:
#define DIPSW_SETTINGS  0
#define DIPSW_CHUTES    1
#define DIPSW_CTRL      2
#define DIPSW_ID0       3
#define DIPSW_ID1       4
#define DIPSW_MULTI     5
#define DIPSW_FREEPLAY  6
#define DIPSW_FREEZE    7

// VRAM zones:
#define SCB1            0x0000   // Sprite tilemaps
#define FIXMAP          0x7000
#define SCB2            0x8000   // Sprite shrink values
#define SCB3            0x8200   // Sprite Y positions, heights and flags
#define SCB4            0x8400   // Sprite X positions

// Basic colors:
#define BLACK           0x8000
#define DARKGREY        0x8222
#define MIDRED          0x4700
#define RED             0x4F00
#define MIDGREEN        0x2070
#define GREEN           0x20F0
#define MIDBLUE         0x1007
#define BLUE            0x100F
#define MIDYELLOW       0x6770
#define YELLOW          0x6FF0
#define MIDMAGENTA      0x5707
#define MAGENTA         0x5F0F
#define MIDCYAN         0x3077
#define CYAN            0x30FF
#define ORANGE          0x6F70
#define MIDGREY         0x7777
#define WHITE           0x7FFF

// Zones:
#define RAMSTART        0x100000   // 68k work RAM
#define PALETTES        ((vu16*)0x400000)   // Palette RAM
#define BACKDROP        (PALETTES+(16*2*256)-2)
#define MEMCARD         0x800000   // Memory card
#define SYSROM          0xC00000   // System ROM

// Registers:
#define REG_P1CNT       0x300000
#define REG_DIPSW       0x300001   // Dipswitches/Watchdog
#define REG_SOUND       ((vu8*)0x320000)   // Z80 I/O
#define REG_STATUS_A    0x320001
#define REG_P2CNT       0x340000
#define REG_STATUS_B    0x380000
#define REG_POUTPUT     0x380001   // Joypad port outputs
#define REG_SLOT        0x380021   // Slot select

#define REG_NOSHADOW    0x3A0001   // Video output normal/dark
#define REG_SHADOW      0x3A0011
#define REG_BRDFIX      0x3A000B   // Use embedded fix tileset
#define REG_CRTFIX      0x3A001B   // Use game fix tileset
#define REG_PALBANK1    0x3A000F   // Use palette bank 1
#define REG_PALBANK0    0x3A001F   // Use palette bank 0 (default)

#define REG_VRAMADDR    0x3C0000
#define REG_VRAMRW      0x3C0002
#define REG_VRAMMOD     0x3C0004
#define REG_LSPCMODE    0x3C0006
#define REG_TIMERHIGH   0x3C0008
#define REG_TIMERLOW    0x3C000A
#define REG_IRQACK      0x3C000C
#define REG_TIMERSTOP   0x3C000E

// System ROM calls:
#define SYS_INT1          0xC00438
#define SYS_RETURN        0xC00444
#define SYS_IO            0xC0044A
#define SYS_CREDIT_CHECK  0xC00450
#define SYS_CREDIT_DOWN   0xC00456
#define SYS_READ_CALENDAR 0xC0045C   // MVS only
#define SYS_CARD          0xC00468
#define SYS_CARD_ERROR    0xC0046E
#define SYS_HOWTOPLAY     0xC00474   // MVS only
#define SYS_FIX_CLEAR     0xC004C2
#define SYS_LSP_1ST       0xC004C8   // Clear sprites
#define SYS_MESS_OUT      0xC004CE

// RAM locations:
#define BIOS_SYSTEM_MODE  0x10FD80
#define BIOS_MVS_FLAG     0x10FD82
#define BIOS_COUNTRY_CODE 0x10FD83
#define BIOS_GAME_DIP     0x10FD84   // Start of soft DIPs settings (up to 0x10FD93)

// Set by SYS_IO:
#define BIOS_P1STATUS   0x10FD94
#define BIOS_P1PREVIOUS 0x10FD95
#define BIOS_P1CURRENT  0x10FD96
#define BIOS_P1CHANGE   0x10FD97
#define BIOS_P1REPEAT   0x10FD98
#define BIOS_P1TIMER    0x10FD99

#define BIOS_P2STATUS   0x10FD9A
#define BIOS_P2PREVIOUS 0x10FD9B
#define BIOS_P2CURRENT  0x10FD9C
#define BIOS_P2CHANGE   0x10FD9D
#define BIOS_P2REPEAT   0x10FD9E
#define BIOS_P2TIMER    0x10FD9F

// find more info on player 3 and player 4 registers

#define BIOS_STATCURNT    0x10FDAC
#define BIOS_STATCHANGE   0x10FDAD
#define BIOS_USER_REQUEST 0x10FDAE
#define BIOS_USER_MODE    0x10FDAF
#define BIOS_START_FLAG   0x10FDB4
#define BIOS_MESS_POINT   0x10FDBE
#define BIOS_MESS_BUSY    0x10FDC2

// Memory card:
#define BIOS_CRDF       0x10FDC4   // Byte: function to perform when calling BIOSF_CRDACCESS
#define BIOS_CRDRESULT  0x10FDC6   // Byte: 00 on success, else 80+ and encodes the error
#define BIOS_CRDPTR     0x10FDC8   // Longword: pointer to read from/write to
#define BIOS_CRDSIZE    0x10FDCC   // Word: how much data to read/write from/to card
#define BIOS_CRDNGH     0x10FDCE   // Word: usually game NGH. Unique identifier for the game that owns the save file
#define BIOS_CRDFILE    0x10FDD0   // Word: each NGH has up to 16 save files associated with

// Calendar, MVS only (in BCD):
#define BIOS_YEAR       0x10FDD2   // Last 2 digits of year
#define BIOS_MONTH      0x10FDD3
#define BIOS_DAY        0x10FDD4
#define BIOS_WEEKDAY    0x10FDD5   // Sunday = 0, Monday = 1 ... Saturday = 6
#define BIOS_HOUR       0x10FDD6   // 24 hour time
#define BIOS_MINUTE     0x10FDD7
#define BIOS_SECOND     0x10FDD8

#define BIOS_SELECT_TIMER 0x10FDDA   // Byte: game start countdown
#define BIOS_DEVMODE      0x10FE80   // Byte: non-zero for developer mode

// Upload system ROM call:
#define BIOS_UPDEST     0x10FEF4   // Longword
#define BIOS_UPSRC      0x10FEF8   // Longword
#define BIOS_UPSIZE     0x10FEFC   // Longword
#define BIOS_UPZONE     0x10FEDA   // Byte: zone (0=PRG, 1=FIX, 2=SPR, 3=Z80, 4=PCM, 5=PAT)
#define BIOS_UPBANK     0x10FEDB   // Byte: bank

#define SOUND_STOP      0xD00046

// Button definitions:
#define CNT_UP	        0
#define CNT_DOWN 1
#define CNT_LEFT 2
#define CNT_RIGHT 3
#define CNT_A	        4
#define CNT_B	        5
#define CNT_C	        6
#define CNT_D	        7
#define CNT_START1      0
#define CNT_SELECT1     1
#define CNT_START2      2
#define CNT_SELECT2     3

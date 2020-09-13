#ifndef NEOGEO_INPUT_H_INCLUDED
#define NEOGEO_INPUT_H_INCLUDED

#include "neogeo_defines.h"

typedef struct {
    u8 D     : 1;
    u8 C     : 1;
    u8 B     : 1;
    u8 A     : 1;
    u8 right : 1;
    u8 left  : 1;
    u8 down  : 1;
    u8 up    : 1;
} NormalInput;

typedef struct {
    u8 select_p4 : 1;
    u8 start_p4  : 1;
    u8 select_p3 : 1;
    u8 start_p3  : 1;
    u8 select_p2 : 1;
    u8 start_p2  : 1;
    u8 select_p1 : 1;
    u8 start_p1  : 1;
} InputStatus;

#endif // NEOGEO_INPUT_H_INCLUDED

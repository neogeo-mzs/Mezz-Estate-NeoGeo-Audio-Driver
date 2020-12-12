#include "neogeo/neogeo.h"

void __attribute__((optimize("O0"))) wait_loop(int loops)
{
    for(u16 i = 0; i < loops; ++i);
}
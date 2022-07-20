#ifndef UTILS_H
#define UTILS_H

#define CLAMP(x, min, max)  (((x) > (max)) ? (max) : (((x) < (min)) ? (min) : (x)))
#define WRAP(x, min, max)   ( (x)>=(max) ? (x)+(min)-(max) : ( ((x)<(min)) ? (x)+(max)-(min) : (x) ) )

void __attribute__((optimize("O0"))) wait_loop(int loops);

#endif
#pragma once
#include <stdint.h>

struct Chip8;
typedef struct Chip8 Chip8;

Chip8* chip8_allocate();
void chip8_initialize(Chip8*);
void chip8_deallocate(Chip8*);

void chip8_loadProgramFromPath(Chip8*,char*);
void chip8_preformNextInstruction(Chip8*);

void chip8_fixedUpdate(Chip8*);

void chip8_setKeyPressed(Chip8*, uint8_t, bool);

uint8_t chip8_getPixel(Chip8*,int x,int y);
bool chip8_getBuzzer(Chip8*);

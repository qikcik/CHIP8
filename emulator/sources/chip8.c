#include "chip8.h"

#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#define STACK_SIZE 16
#define MEMORY_SIZE 4096
#define GENERAL_REG_SIZE 16

#define KEY_SIZE 16
#define KEY_NULL_ID 255
#define KEY_INVALID_ID 254

#define FRAMEBUFFER_X 64
#define FRAMEBUFFER_Y 32

#define DEBUG_PRINT false

struct Chip8 {
    int tickFromFixedUpdate;

    uint8_t v_reg[GENERAL_REG_SIZE];
    uint16_t i_reg;
    uint16_t pc_reg;

    uint8_t sp_reg;
    uint8_t delay_timer;
    uint8_t sound_timer;

    uint16_t stack[STACK_SIZE];
    uint8_t memory[MEMORY_SIZE];
    uint32_t screen[FRAMEBUFFER_Y][FRAMEBUFFER_X];

    bool key[KEY_SIZE];
    bool prev_key[KEY_SIZE];
};

Chip8* chip8_allocate() {
    return malloc(sizeof(Chip8));
}

void chip8_initialize(Chip8* c) {

    c->tickFromFixedUpdate = 0;

    for(int idx = 0; idx != GENERAL_REG_SIZE; idx++)
        c->v_reg[idx] = 0;

    c->i_reg = 0;
    c->pc_reg = 0x200;

    c->sp_reg = 0;
    c->delay_timer = 0;
    c->sound_timer = 0;

    for(int idx = 0; idx != KEY_SIZE; idx++) {
        c->key[idx] = false;
        c->prev_key[idx] = false;
    }


    for(int Yidx = 0; Yidx != FRAMEBUFFER_Y; Yidx++)
        for(int Xidx = 0; Xidx != FRAMEBUFFER_X; Xidx++)
            c->screen[Yidx][Xidx] = 0;

    c->screen[2][2] = 1;

    for(int idx = 0; idx != MEMORY_SIZE; idx++)
        c->memory[idx] = 0;

    static uint8_t font_data[] = {
        0b11100000,
        0b10100000,
        0b10100000,
        0b10100000,
        0b11100000,

        0b01000000,
        0b01000000,
        0b01000000,
        0b01000000,
        0b01000000,

        0b11100000,
        0b00100000,
        0b11100000,
        0b10000000,
        0b11100000,

        0b11100000,
        0b00100000,
        0b11100000,
        0b00100000,
        0b11100000,

        0b10000000,
        0b10100000,
        0b10100000,
        0b11100000,
        0b00100000,

        0b11100000,
        0b10000000,
        0b11100000,
        0b00100000,
        0b11100000,

        0b11100000,
        0b10000000,
        0b11100000,
        0b10100000,
        0b11100000,

        0b11100000,
        0b00100000,
        0b00100000,
        0b00100000,
        0b00100000,

        0b11100000,
        0b10100000,
        0b11100000,
        0b10100000,
        0b11100000,

        0b11100000,
        0b10100000,
        0b11100000,
        0b00100000,
        0b11100000,

        0b11100000,
        0b10100000,
        0b11100000,
        0b10100000,
        0b10100000,

        0b11000000,
        0b10100000,
        0b11100000,
        0b10100000,
        0b11000000,

        0b11100000,
        0b10000000,
        0b10000000,
        0b10000000,
        0b11100000,

        0b11000000,
        0b10100000,
        0b10100000,
        0b10100000,
        0b11000000,

        0b11100000,
        0b10000000,
        0b11100000,
        0b10000000,
        0b11100000,

        0b11100000,
        0b10000000,
        0b11000000,
        0b10000000,
        0b10000000,
    };

    for(int idx=0;idx != sizeof(font_data)/sizeof(uint8_t);idx++)
        c->memory[idx] = font_data[idx];
}

void chip8_deallocate(Chip8* c) {
    free(c);
}

void chip8_loadProgramFromPath(Chip8* c , char* filename) {
    long rom_length;
    uint8_t *rom_buffer;

    FILE *rom = fopen(filename, "rb");
    if (rom != NULL) {
        // Get the size of the rom to allocate memory for a buffer
        fseek(rom, 0, SEEK_END);
        rom_length = ftell(rom);
        rewind(rom);

        rom_buffer = (uint8_t*) malloc(sizeof(uint8_t) * rom_length);
        if (rom_buffer == NULL) {
            printf("ERROR: Out of memory\n");

            exit(EXIT_FAILURE);
        }

        fread(rom_buffer, sizeof(uint8_t), rom_length, rom);

        if ((0xFFF - 0x200) >= rom_length) {
            for(int i = 0; i < rom_length; i++) {
                c->memory[i + 0x200] = rom_buffer[i];
            }
        }
        else {
            printf("ERROR: ROM file too large\n");
            exit(EXIT_FAILURE);
        }

    }
    else {
        printf("ERROR: ROM file does not exist\n");
        exit(EXIT_FAILURE);
    }

    fclose(rom);
    free(rom_buffer);
}

uint16_t fetch_opcode(Chip8* c) {
    const uint8_t ms = c->memory[c->pc_reg];
    const uint8_t ls = c->memory[c->pc_reg + 1];
    c->pc_reg += 2;
    if(c->pc_reg > MEMORY_SIZE-1) c->pc_reg = MEMORY_SIZE-1;
    return (ms << 8) | ls;
}

uint8_t chip8_getPixel(Chip8* c,int x,int y) {
    return c->screen[y][x];
}

bool chip8_getBuzzer(Chip8* c) {
    return c->sound_timer != 0;
}

void chip8_preformNextInstruction(Chip8* c) {

    const uint16_t opcode = fetch_opcode(c);
    if(DEBUG_PRINT) printf("at %x instruction %x: ",c->pc_reg-2,opcode);

    if(opcode == 0x00E0) { // 00E0 - CLS
        if( c->tickFromFixedUpdate == 0)
        {
            if(DEBUG_PRINT) printf("display_clear()");
            for(int Yidx = 0; Yidx != FRAMEBUFFER_Y; Yidx++)
                for(int Xidx = 0; Xidx != FRAMEBUFFER_X; Xidx++)
                    c->screen[Yidx][Xidx] = 0;
        }
        else {
            c->pc_reg -= 2;
            if (DEBUG_PRINT) printf("display_clear() - wait for vsync");
        }
    }
    else if(opcode == 0x00EE) { // 00EE - RET
        if(DEBUG_PRINT) printf("return");
        assert(c->sp_reg > 0);
        c->pc_reg = c->stack[c->sp_reg];
        c->sp_reg--;
    }
    else if((opcode & 0xF000) == 0x0000) { //0nnn - SYS addr
        const uint16_t arg = (opcode & 0x0FFF);
        printf("sys %i \n",arg);

        for(int idx = 0; idx != GENERAL_REG_SIZE; idx++)
            printf("debug: v_%x = %x \n",idx,c->v_reg[idx]);
    }
    else if((opcode & 0xF000) == 0x1000) { //1nnn - JP addr
        const uint16_t arg = (opcode & 0x0FFF);
        c->pc_reg = arg;
        if(DEBUG_PRINT) printf("goto %x",arg);
    }
    else if((opcode & 0xF000) == 0x2000) { //2nnn - CALL addr
        assert(c->sp_reg < STACK_SIZE-1);
        const uint16_t arg = (opcode & 0x0FFF);

        c->sp_reg++;
        c->stack[c->sp_reg] = c->pc_reg;
        c->pc_reg = arg;
        if(DEBUG_PRINT) printf("*(%x)()",arg);
    }
    else if((opcode & 0xF000) == 0x3000) { //3xkk - SE Vx, byte
        const uint8_t selectedReg = (opcode & 0x0F00) >> 2*4;
        if(c->v_reg[selectedReg] == (opcode & 0x00FF))
            c->pc_reg += 2;
        if(DEBUG_PRINT) printf("if (V_%x == %x)",selectedReg,(opcode & 0x00FF));
    }
    else if((opcode & 0xF000) == 0x4000) { // 4xkk - SNE Vx, byte
        const uint8_t selectedReg = (opcode & 0x0F00) >> 2*4;
        if(c->v_reg[selectedReg] != (opcode & 0x00FF))
            c->pc_reg += 2;
        if(DEBUG_PRINT) printf("if (V_%x != %x)",selectedReg,(opcode & 0x00FF));
    }
    else if((opcode & 0xF000) == 0x5000) { // 5xy0 - SE Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        if(c->v_reg[selectedRegX] == c->v_reg[selectedRegY])
            c->pc_reg += 2;
        if(DEBUG_PRINT) printf("if (V_%x == V_%x)",selectedRegX,selectedRegY);
    }
    else if((opcode & 0xF000) == 0x6000) { // 6xkk - LD Vx, byte
        const uint8_t selectedReg = (opcode & 0x0F00) >> 2*4;
        c->v_reg[selectedReg] = (opcode & 0x00FF);

        if(DEBUG_PRINT) printf("V_%x = %x", selectedReg, (opcode & 0x00FF));
    }
    else if((opcode & 0xF000) == 0x7000) { // 7xkk - ADD Vx, byte
        const uint8_t selectedReg = (opcode & 0x0F00) >> 2*4;
        c->v_reg[selectedReg] += (opcode & 0x00FF);
        if(DEBUG_PRINT) printf("V_%x += %x", selectedReg, (opcode & 0x00FF));
    }
    else if((opcode & 0xF00F) == 0x8000) { // 8xy0 - LD Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegY];
        if(DEBUG_PRINT) printf("V_%x = %x", selectedRegX, selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8001) { // 8xy1 - OR Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegX] | c->v_reg[selectedRegY];
        c->v_reg[GENERAL_REG_SIZE-1] = 0;
        if(DEBUG_PRINT) printf("V_%x |= %x", selectedRegX, selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8002) { // 8xy2 - AND Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegX] & c->v_reg[selectedRegY];
        c->v_reg[GENERAL_REG_SIZE-1] = 0;
        if(DEBUG_PRINT) printf("V_%x &= %x", selectedRegX, selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8003) { // 8xy3 - XOR Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegX] ^ c->v_reg[selectedRegY];
        c->v_reg[GENERAL_REG_SIZE-1] = 0;
        if(DEBUG_PRINT) printf("V_%x ^= %x", selectedRegX, selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8004) { // 8xy4 - ADD Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        const uint16_t sum = c->v_reg[selectedRegX] + c->v_reg[selectedRegY];
        c->v_reg[selectedRegX] = sum;
        c->v_reg[GENERAL_REG_SIZE-1] = (sum > 255);
        if(DEBUG_PRINT) printf("V_%x += %x", selectedRegX, selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8005) { // 8xy5 - SUB Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;

        const auto carry = (c->v_reg[selectedRegX] >= c->v_reg[selectedRegY]);
        c->v_reg[selectedRegX] = c->v_reg[selectedRegX] - c->v_reg[selectedRegY];
        c->v_reg[GENERAL_REG_SIZE-1] = carry;
        if(DEBUG_PRINT) printf("V_%x = V_%x - V_%x", selectedRegX,selectedRegX,selectedRegY);
    }
    else if((opcode & 0xF00F) == 0x8006) { // 8xy6 - SHR Vx {, Vy}
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegY];

        const auto carry = c->v_reg[selectedRegX] & 0x1;
        c->v_reg[selectedRegX] >>= 1;
        c->v_reg[GENERAL_REG_SIZE-1] = carry;
        if(DEBUG_PRINT) printf("V_%x >>= 1", selectedRegX);
    }
    else if((opcode & 0xF00F) == 0x8007) { // 8xy7 - SUBN Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;

        c->v_reg[selectedRegX] = c->v_reg[selectedRegY] - c->v_reg[selectedRegX];
        c->v_reg[GENERAL_REG_SIZE-1] = (c->v_reg[selectedRegY] > c->v_reg[selectedRegX]);
        if(DEBUG_PRINT) printf("V_%x = V_%x - V_%x", selectedRegX,selectedRegY,selectedRegX);
    }
    else if((opcode & 0xF00F) == 0x800E) { // 8xyE - SHL Vx {, Vy}
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        c->v_reg[selectedRegX] = c->v_reg[selectedRegY];

        const auto carry = c->v_reg[selectedRegX] >> 7;
        c->v_reg[selectedRegX] <<= 1;
        c->v_reg[GENERAL_REG_SIZE-1] = carry;
        if(DEBUG_PRINT) printf("V_%x <<= 1", selectedRegX);
    }
    else if((opcode & 0xF000) == 0x9000) { // 9xy0 - SNE Vx, Vy
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        const uint8_t selectedRegY = (opcode & 0x00F0) >> 1*4;
        if(c->v_reg[selectedRegX] != c->v_reg[selectedRegY])
            c->pc_reg += 2;
        if(DEBUG_PRINT) printf("if (V_%x != V_%x)", selectedRegX,selectedRegY);
    }
    else if((opcode & 0xF000) == 0xA000) { // Annn - LD I, addr
        c->i_reg = (opcode & 0x0FFF);

        if(DEBUG_PRINT) printf("I = %x", (opcode & 0x0FFF));
    }
    else if((opcode & 0xF000) == 0xB000) { // Bnnn - JP V0, addr
        c->pc_reg = (opcode & 0x0FFF) + c->v_reg[0];
        if(DEBUG_PRINT) printf("goto %x + %x",c->v_reg[0],(opcode & 0x0FFF));
    }
    else if((opcode & 0xF000) == 0xC000) { // Cxkk - RND Vx, byte
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->v_reg[selectedRegX] = (rand() & (opcode & 0x00FF));
        if(DEBUG_PRINT) printf("V_%x = rand() & %x",c->v_reg[0],(opcode & 0x0FFF));
    }
    else if((opcode & 0xF000) == 0xD000) { // Dxyn - DRW Vx, Vy, nibble
        uint8_t target_v_reg_x = (opcode & 0x0F00) >> 8;
        uint8_t target_v_reg_y = (opcode & 0x00F0) >> 4;
        uint8_t sprite_height = opcode & 0x000F;
        uint8_t x_location = c->v_reg[target_v_reg_x] & FRAMEBUFFER_X-1;
        uint8_t y_location = c->v_reg[target_v_reg_y] & FRAMEBUFFER_Y-1;
        uint8_t pixel;

        if( /*c->tickFromFixedUpdate == 0*/ true) {
            // Reset collision register to FALSE
            c->v_reg[0xF] = 0;
            for (int y_coordinate = 0; y_coordinate < sprite_height && (y_location+y_coordinate) < FRAMEBUFFER_Y ; y_coordinate++) {
                pixel = c->memory[c->i_reg + y_coordinate];
                for (int x_coordinate = 0; x_coordinate < 8  && (x_location+x_coordinate) < FRAMEBUFFER_X ; x_coordinate++) {
                    if ( pixel & (0x80 >> x_coordinate) ) {
                        if (c->screen[y_location + y_coordinate][x_location + x_coordinate] == 1) {
                            c->v_reg[0xF] = 1;
                        }
                        c->screen[y_location + y_coordinate][x_location + x_coordinate] ^= 1;
                    }
                }
            }
            if (DEBUG_PRINT) printf("draw(V_%x,V_%x,%x)", target_v_reg_x, target_v_reg_y, sprite_height);
        }
        else {
            c->pc_reg -= 2;
            if (DEBUG_PRINT) printf("draw(V_%x,V_%x,%x) - wait for vsync", target_v_reg_x, target_v_reg_y, sprite_height);
        }
    }
    else if((opcode & 0xF0FF) == 0xE09E) { // Ex9E - SKP Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;

        if(c->key[c->v_reg[selectedRegX]])
            c->pc_reg += 2;

        if(DEBUG_PRINT) printf("if(pressedKey() == V_%x)",selectedRegX);
    }

    else if((opcode & 0xF0FF) == 0xE0A1) { // ExA1 - SKNP Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;

        if(!c->key[c->v_reg[selectedRegX]])
            c->pc_reg += 2;

        if(DEBUG_PRINT) printf("if(pressedKey() != V_%x)",selectedRegX);
    }
    else if((opcode & 0xF0FF) == 0xF007) { // LD Vx, DT
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;

        c->v_reg[selectedRegX] = c->delay_timer;
        if(DEBUG_PRINT) printf("V_%x = get_delay()",selectedRegX);
    }

    else if((opcode & 0xF0FF) == 0xF00A) { // Fx0A - LD Vx, K
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;

        bool pressed = false;
        for(int idx = 0; idx != KEY_SIZE; idx++) {
            if( c->prev_key[idx] && !c->key[idx] ) {
                pressed = true;
                c->v_reg[selectedRegX] = idx;
            }
        }
        if(!pressed)
            c->pc_reg -= 2;

        if(DEBUG_PRINT) printf("do { V_%x = pressedKey() } while(pressedKey() == NO_PRESSED)",selectedRegX);
    }

    else if((opcode & 0xF0FF) == 0xF015) { //Fx15 - LD DT, Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->delay_timer = c->v_reg[selectedRegX];

        if(DEBUG_PRINT) printf("set_delay(V_%x)",selectedRegX);
    }

    else if((opcode & 0xF0FF) == 0xF018) { //Fx18 - LD ST, Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->sound_timer = c->v_reg[selectedRegX];

        if(DEBUG_PRINT) printf("set_sound(V_%x)",selectedRegX);
    }

    else if((opcode & 0xF0FF) == 0xF01E) { // Fx1E - ADD I, Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->i_reg += c->v_reg[selectedRegX];
        if(DEBUG_PRINT) printf("I += V_%x",selectedRegX);
    }
    else if((opcode & 0xF0FF) == 0xF029) { //Fx29 - LD F, Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->i_reg = c->v_reg[selectedRegX] * 5;
        if(DEBUG_PRINT) printf(" I = sprite_addr[V_%x]",selectedRegX);
    }
    else if((opcode & 0xF0FF) == 0xF033) { //Fx33 - LD B, Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        c->memory[c->i_reg+0] = ((int)c->v_reg[selectedRegX] % 1000)/100;
        c->memory[c->i_reg+1] = ((int)c->v_reg[selectedRegX] % 100)/10;
        c->memory[c->i_reg+2] = (int)c->v_reg[selectedRegX] % 10;
        if(DEBUG_PRINT) printf("*(I+0) = BCD(V_%x,100); *(I+1) = BCD(V_%x,10); *(I+2) = BCD(V_%x,1)",selectedRegX,selectedRegX,selectedRegX);
    }
    else if((opcode & 0xF0FF) == 0xF055) { //LD [I], Vx
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        for(int idx=0;idx <= selectedRegX;idx++) {
            c->memory[c->i_reg+idx] = c->v_reg[idx];
        }
        if(DEBUG_PRINT) printf("reg_dump(V_0,V_%x,I)",selectedRegX);
    }
    else if((opcode & 0xF0FF) == 0xF065) { //LD Vx, [I]
        const uint8_t selectedRegX = (opcode & 0x0F00) >> 2*4;
        for(int idx=0;idx <= selectedRegX;idx++) {
            c->v_reg[idx] = c->memory[c->i_reg+idx];
        }
        if(DEBUG_PRINT) printf("reg_load(V_0,V_%x,I)",selectedRegX);
    }
    else {
        printf("unsuported instruction %d \n",opcode);
    }

    if(DEBUG_PRINT) printf("\n");
    c->tickFromFixedUpdate++;
}

void chip8_fixedUpdate(Chip8* c) {
    c->tickFromFixedUpdate = 0;
    if(c->delay_timer > 0) c->delay_timer -= 1;
    if(c->sound_timer > 0) c->sound_timer -= 1;

    for(int idx = 0; idx != KEY_SIZE; idx++) {
        c->prev_key[idx] = c->key[idx];
    }
}

void chip8_setKeyPressed(Chip8* c, uint8_t inKey, bool inStatus) {
    c->key[inKey] = inStatus;
}

#include <stdio.h>

#include "raylib.h"
#include "chip8.h"
#include <time.h>
#include <math.h>
#include <malloc.h>

#define SCREEN_X 64
#define SCREEN_Y 32

#define MAX_SAMPLES 512
#define MAX_SAMPLES_PER_UPDATE  4096
#define SAMPLE_RATE  44100

float frequency = 440.0f;
float sineIdx = 0.0f;

bool audioEnabled = false;

void AudioInputCallback(void *buffer, unsigned int frames)
{
    float incr = frequency/(float)SAMPLE_RATE;
    short *d = (short *)buffer;

    for (unsigned int i = 0; i < frames; i++)
    {
        d[i] = (short)(8000.0f*sinf(2*PI*sineIdx));

        if(audioEnabled) {
            sineIdx += incr;
            if (sineIdx > 1.0f) sineIdx -= 1.0f;
        }
    }
}

int main(int argc, char * argv[])
{
    srand(time(NULL));
    InitAudioDevice();
    SetAudioStreamBufferSizeDefault(MAX_SAMPLES_PER_UPDATE);
    AudioStream stream = LoadAudioStream(SAMPLE_RATE, 16, 1);
    SetAudioStreamCallback(stream, AudioInputCallback);
    PlayAudioStream(stream);

    Chip8* c = chip8_allocate();
    chip8_initialize(c);

    if(argc > 1)
        chip8_loadProgramFromPath(c,argv[1]);
    else
        chip8_loadProgramFromPath(c,"./output.ch8");

    const int screenWidth = SCREEN_X*8;
    const int screenHeight = SCREEN_Y*8;

    InitWindow(screenWidth, screenHeight, "chip8");

    SetTargetFPS(-1);
    double lastTime = (double)clock()/CLOCKS_PER_SEC;
    double lastDrawTime = lastTime;

    while (!WindowShouldClose())
    {
        audioEnabled = chip8_getBuzzer(c);
        chip8_setKeyPressed(c,0x1,IsKeyDown(KEY_ONE));
        chip8_setKeyPressed(c,0x2,IsKeyDown(KEY_TWO));
        chip8_setKeyPressed(c,0x3,IsKeyDown(KEY_THREE));
        chip8_setKeyPressed(c,0xC,IsKeyDown(KEY_FOUR));

        chip8_setKeyPressed(c,0x4,IsKeyDown(KEY_Q));
        chip8_setKeyPressed(c,0x5,IsKeyDown(KEY_W));
        chip8_setKeyPressed(c,0x6,IsKeyDown(KEY_E));
        chip8_setKeyPressed(c,0xD,IsKeyDown(KEY_R));

        chip8_setKeyPressed(c,0x7,IsKeyDown(KEY_A));
        chip8_setKeyPressed(c,0x8,IsKeyDown(KEY_S));
        chip8_setKeyPressed(c,0x9,IsKeyDown(KEY_D));
        chip8_setKeyPressed(c,0xE,IsKeyDown(KEY_F));

        chip8_setKeyPressed(c,0xA,IsKeyDown(KEY_Z));
        chip8_setKeyPressed(c,0x0,IsKeyDown(KEY_X));
        chip8_setKeyPressed(c,0xB,IsKeyDown(KEY_C));
        chip8_setKeyPressed(c,0xF,IsKeyDown(KEY_V));

        lastTime  = (double)clock()/CLOCKS_PER_SEC;
        while(lastTime - lastDrawTime  < 1.0/60.0)
        {
            lastTime  = (double)clock()/CLOCKS_PER_SEC;
            chip8_preformNextInstruction(c);
        }

        lastDrawTime = lastTime;
        chip8_fixedUpdate(c);

        BeginDrawing();
        ClearBackground(BLACK);
        for(int x = 0; x != SCREEN_X; x++)
            for(int y = 0; y != SCREEN_Y; y++)
                if(chip8_getPixel(c,x,y))
                    DrawRectangle(x*8,y*8,8,8,DARKGREEN);
        EndDrawing();
    }

    UnloadAudioStream(stream);   // Close raw audio stream and delete buffers from RAM
    CloseAudioDevice();         // Close audio device (music streaming is automatically stopped)

    CloseWindow();
    return 0;
}
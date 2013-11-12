#ifndef _chip8_cpu_h_
#define _chip8_cpu_h_

#include <stdint.h>

interface chip8_keys;
interface chip8_screen;

#define CHIP8_MEM_BYTES 0x1000
#define CHIP8_RESERVED_MEM 0x200
#define CHIP8_MAX_IMAGE_SIZE (CHIP8_MEM_BYTES - CHIP8_RESERVED_MEM)

interface chip8_callbacks {
  void load_image(uint8_t mem[CHIP8_MAX_IMAGE_SIZE]);
  void exit();
};

void chip8_cpu(client interface chip8_keys keys,
               client interface chip8_screen screen,
               client interface chip8_callbacks);

#endif /* _chip8_cpu_h_ */

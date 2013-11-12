#include "chip8_cpu.h"
#include "chip8_keys.h"
#include "chip8_screen.h"
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#define DEBUG_UNIT CHIP8_CPU
#include "debug_print.h"

#define TICKS_PER_SECOND 60

// Not sure what to use here - some emulators use 10, others 12
// TODO use something higher in SCHIP-48 mode?
#define OPCODES_PER_TICK 12

// See http://devernay.free.fr/hacks/chip8/C8TECH10.HTM
static const uint8_t fonts[] = {
  0xF0, 0x90, 0x90, 0x90, 0xF0, // 0
  0x20, 0x60, 0x20, 0x20, 0x70, // 1
  0xF0, 0x10, 0xF0, 0x80, 0xF0, // 2
  0xF0, 0x10, 0xF0, 0x10, 0xF0, // 3
  0x90, 0x90, 0xF0, 0x10, 0x10, // 4
  0xF0, 0x80, 0xF0, 0x10, 0xF0, // 5
  0xF0, 0x80, 0xF0, 0x90, 0xF0, // 6
  0xF0, 0x10, 0x20, 0x40, 0x40, // 7
  0xF0, 0x90, 0xF0, 0x90, 0xF0, // 8
  0xF0, 0x90, 0xF0, 0x10, 0xF0, // 9
  0xF0, 0x90, 0xF0, 0x90, 0x90, // A
  0xE0, 0x90, 0xE0, 0x90, 0xE0, // B
  0xF0, 0x80, 0x80, 0x80, 0xF0, // C
  0xE0, 0x90, 0x90, 0x90, 0xE0, // D
  0xF0, 0x80, 0xF0, 0x80, 0xF0, // E
  0xF0, 0x80, 0xF0, 0x80, 0x80  // F
};

static const uint8_t bigfonts[] = {
  0xFF, 0xFF, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xFF, 0xFF, // 0
  0x18, 0x78, 0x78, 0x18, 0x18, 0x18, 0x18, 0x18, 0xFF, 0xFF, // 1
  0xFF, 0xFF, 0x03, 0x03, 0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, // 2
  0xFF, 0xFF, 0x03, 0x03, 0xFF, 0xFF, 0x03, 0x03, 0xFF, 0xFF, // 3
  0xC3, 0xC3, 0xC3, 0xC3, 0xFF, 0xFF, 0x03, 0x03, 0x03, 0x03, // 4
  0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, 0x03, 0x03, 0xFF, 0xFF, // 5
  0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, 0xC3, 0xC3, 0xFF, 0xFF, // 6
  0xFF, 0xFF, 0x03, 0x03, 0x06, 0x0C, 0x18, 0x18, 0x18, 0x18, // 7
  0xFF, 0xFF, 0xC3, 0xC3, 0xFF, 0xFF, 0xC3, 0xC3, 0xFF, 0xFF, // 8
  0xFF, 0xFF, 0xC3, 0xC3, 0xFF, 0xFF, 0x03, 0x03, 0xFF, 0xFF, // 9
  0x7E, 0xFF, 0xC3, 0xC3, 0xC3, 0xFF, 0xFF, 0xC3, 0xC3, 0xC3, // A
  0xFC, 0xFC, 0xC3, 0xC3, 0xFC, 0xFC, 0xC3, 0xC3, 0xFC, 0xFC, // B
  0x3C, 0xFF, 0xC3, 0xC0, 0xC0, 0xC0, 0xC0, 0xC3, 0xFF, 0x3C, // C
  0xFC, 0xFE, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xC3, 0xFE, 0xFC, // D
  0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, // E
  0xFF, 0xFF, 0xC0, 0xC0, 0xFF, 0xFF, 0xC0, 0xC0, 0xC0, 0xC0  // F
};

static uint8_t extractX(uint16_t val)
{
  return (val >> 8) & 0xf;
}

static uint8_t extractY(uint16_t val)
{
  return (val >> 4) & 0xf;
}

static uint8_t extractN(uint16_t val)
{
  return val & 0xf;
}

static uint8_t extractNN(uint16_t val)
{
  return val & 0xff;
}

static uint16_t extractNNN(uint16_t val)
{
  return val & 0xfff;
}

#define STACK_SIZE 16

enum cpu_mode {
  MODE_CHIP8,
  MODE_SCHIP48
};

// Some useful links:
// Cosmac VIP manual - http://chip8.com/cosmacvip/VIP_Manual.pdf
// Chip-8 on the COSMAC VIP - http://laurencescotford.co.uk/?p=242

void chip8_cpu(client interface chip8_keys keys,
		       client interface chip8_screen screen,
               client interface chip8_callbacks callbacks)
{
  uint8_t mem[CHIP8_MEM_BYTES] = {0};
  unsigned stack[STACK_SIZE] = {0};
  unsigned SP = 0;
  uint8_t V[16] = {0};
  uint16_t I = 0;
  uint16_t PC = 0x200;
  uint8_t hp48_flags[8] = {0};
  unsigned delay_timer = 0;
  unsigned sound_timer = 0;
  enum cpu_mode mode = MODE_CHIP8;

  memcpy(mem, fonts, sizeof(fonts));
  memcpy(&mem[sizeof(fonts)], bigfonts, sizeof(bigfonts));
  callbacks.load_image(&mem[CHIP8_RESERVED_MEM]);

// Casts to avoid array subscript has type char warning
#define VX V[(unsigned)extractX(opcode)]
#define VY V[(unsigned)extractY(opcode)]
#define V0 V[0x0]
#define VF V[0xF]
#define N extractN(opcode)
#define NN extractNN(opcode)
#define NNN extractNNN(opcode)
  while (1) {
    int wait_for_key = 0;
    unsigned wait_for_key_reg;
    for (unsigned remaining_instructions = OPCODES_PER_TICK;
         remaining_instructions > 0;) {
      // Instructions are store most significant byte first.
      uint16_t opcode = (mem[PC % CHIP8_MEM_BYTES] << 8) |
    		            mem[(PC + 1) % CHIP8_MEM_BYTES];
      PC += 2;
      --remaining_instructions;
      switch (opcode >> 12) {
      case 0x0:
        if ((NNN & 0xFF0) == 0x0C0) {
          // Scroll the screen down N pixels (SCHIP-48).
          // Delay until refresh in low resolution mode.
          if (mode == MODE_CHIP8 &&
              remaining_instructions != OPCODES_PER_TICK - 1) {
            remaining_instructions = 0;
            PC -= 2;
          } else {
            debug_printf("SCD %d\n", N);
            screen.scroll_down(N);
          }
        } else {
          switch (NNN) {
          case 0x0E0:
            // Clears the screen.
            debug_printf("CLS\n");
            screen.clear();
            break;
          case 0x0EE:
            // Returns from a subroutine.
            debug_printf("RET\n");
            PC = stack[--SP % STACK_SIZE];
            break;
          case 0x0FB:
            // Scroll the screen right 4 pixels (SCHIP-48).
            // Delay until refresh in low resolution mode.
            if (mode == MODE_CHIP8 &&
                remaining_instructions != OPCODES_PER_TICK - 1) {
              remaining_instructions = 0;
              PC -= 2;
            } else {
              debug_printf("SCR\n");
              screen.scroll_right4();
            }
            break;
          case 0x0FC:
            // Scroll the screen left 4 pixels (SCHIP-48).
            // Delay until refresh in low resolution mode.
            if (mode == MODE_CHIP8 &&
                remaining_instructions != OPCODES_PER_TICK - 1) {
              remaining_instructions = 0;
              PC -= 2;
            } else {
              debug_printf("SCL\n");
              screen.scroll_left4();
            }
            break;
          case 0x00FD:
            // Exit with a successful exit status (SCHIP-48).
            debug_printf("EXIT\n");
            return;
          case 0x00FE:
            debug_printf("LOW\n");
            mode = MODE_CHIP8;
            break;
          case 0x00FF:
            debug_printf("HIGH\n");
            mode = MODE_SCHIP48;
            break;
          }
        }
        break;
      case 0x1:
        // Jumps to address NNN.
        debug_printf("JP %d\n", NNN);
        PC = NNN;
        break;
      case 0x2:
        // Calls subroutine at NNN.
        debug_printf("CALL %d\n", NNN);
        stack[SP++ % STACK_SIZE] = PC;
        PC = NNN;
        break;
      case 0x3:
        // Skips the next instruction if VX equals NN.
        debug_printf("SE V%x(0x%x), %d\n", extractX(opcode), VX, NN);
        if (VX == NN)
          PC += 2;
        break;
      case 0x4:
        // Skips the next instruction if VX doesn't equal NN.
        debug_printf("SNE V%x(0x%x), %d\n", extractX(opcode), VX, NN);
        if (VX != NN)
          PC += 2;
        break;
      case 0x5:
        // Skips the next instruction if VX equals VY.
        debug_printf("SE V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                     extractY(opcode), VY);
        if (VX == VY)
          PC += 2;
        break;
      case 0x6:
        // Sets VX to NN.
        debug_printf("LD V%x, %d\n", extractX(opcode), NN);
        VX = NN;
        break;
      case 0x7:
        // Adds NN to VX.
        debug_printf("ADD V%x(0x%x), %d\n", extractX(opcode), VX, NN);
        VX += NN;
        break;
      case 0x8:
        // Note with this group of instructions VF is written after VX so if
        // you use VF as the VX argument the result will be overwritten (see
        // Chip-8 on the COSMAC VIP).
        switch (N) {
        case 0x0:
          // Sets VX to the value of VY.
          debug_printf("LD V%x, V%x(0x%x)\n", extractX(opcode),
                       extractY(opcode), VY);
          VX = VY;
          break;
        case 0x1:
          // Sets VX to VX or VY.
          debug_printf("OR V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          VX |= VY;
          break;
        case 0x2:
          // Sets VX to VX and VY.
          debug_printf("AND V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          VX &= VY;
          break;
        case 0x3:
          // Sets VX to VX xor VY.
          debug_printf("XOR V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                      extractY(opcode), VY);
          VX ^= VY;
          break;
        case 0x4:
          // Adds VY to VX. VF is set to 1 when there's a carry, and to 0 when
          // there isn't.
          debug_printf("ADD V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          uint8_t result = VX + VY;
          int flag = result < VY;
          VX = result;
          VF = flag;
          break;
        case 0x5:
          // VY is subtracted from VX. VF is set to 0 when there's a borrow, and 1
          // when there isn't.
          debug_printf("SUB V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          uint8_t result = VX - VY;
          int flag = VX >= VY;
          VX = result;
          VF = flag;
          break;
        case 0x6:
          // In the original CHIP-8 interpreter this was an undocumented
          // instruction that shifted VY right by one and stored the result in
          // VX and VY. However most modern interpreters shift VX right by one
          // leave VY unchanged so that is what we do here. See Chip-8 on the
          // COSMAC VIP for more info. VF is set to the value of the least
          // significant bit of VX before the shift.
          debug_printf("SHR V%x(0x%x)\n", extractX(opcode), VX);
          int flag = VX & 0x1;
          VX >>= 1;
          VF = flag;
          break;
        case 0x7:
          // Sets VX to VY minus VX. VF is set to 0 when there's a borrow, and 1
          // when there isn't.
          debug_printf("SUBN V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          uint8_t result = VY - VX;
          int flag = VY >= VX;
          VX = result;
          VF = flag;
          break;
        case 0xE:
          // Shifts VX left by one. On the original CHIP-8 interpreter this
          // shifted VY instead of VY (see comments for SHR). VF is set to the
          // value of the most significant bit of VX before the shift.
          debug_printf("SHL V%x(0x%x)\n", extractX(opcode), VX);
          int flag = VX >> 7;
          VX <<= 1;
          VF = flag;
          break;
        }
        break;
      case 0x9:
        // Skips the next instruction if VX doesn't equal VY.
        debug_printf("SNE V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                     extractY(opcode), VY);
        if (VX != VY)
          PC += 2;
        break;
      case 0xA:
        // Sets I to the address NNN.
        debug_printf("LD I, %d\n", NNN);
        I = NNN;
        break;
      case 0xB:
        // Jumps to the address NNN plus V0.
        debug_printf("JP %d, V0(0x%x)\n", NNN, V0);
        PC = NNN + V0;
        break;
      case 0xC:
        // Sets VX to a random number and NN.
        debug_printf("RND V%x, %d\n", extractX(opcode), NN);
        VX = rand() & NN;
        break;
      case 0xD:
        // Draws a sprite at coordinate (VX, VY) that has a width of 8 pixels
        // and a height of N pixels. Each row of 8 pixels is read as bit-coded
        // (with the most significant bit of each byte displayed on the left)
        // starting from memory location I; I value doesn't change after the
        // execution of this instruction. As described above, VF is set to 1 if
        // any screen pixels are flipped from set to unset when the sprite is
        // drawn, and to 0 if that doesn't happen.
        if (N == 0) {
          // SCHIP-48
          // TODO only in extended mode?
          debug_printf("DRWX V%x(0x%x), V%x(0x%x)\n", extractX(opcode), VX,
                       extractY(opcode), VY);
          // TODO check for error.
          if (mode == MODE_CHIP8)
            VF = screen.draw_sprite8_x2(&mem[I], 16, VX, VY);
          else
            VF = screen.draw_sprite16(&mem[I], VX, VY);
        } else {
          debug_printf("DRW V%x(0x%x), V%x(0x%x), %d\n", extractX(opcode), VX,
                       extractY(opcode), VY, N);
          // TODO check for error.
          if (I + N < CHIP8_MEM_BYTES) {
            if (mode == MODE_CHIP8)
              VF = screen.draw_sprite8_x2(&mem[I], N, VX, VY);
            else
              VF = screen.draw_sprite8(&mem[I], N, VX, VY);
          }
        }
        break;
      case 0xE:
        switch (NN) {
        case 0x9E:
          // Skips the next instruction if the key stored in VX is pressed.
          debug_printf("SKP V%x(0x%x)\n", extractX(opcode), VX);
          if (keys.get_key(VX & 0xF))
            PC += 2;
          break;
        case 0xA1:
          // Skips the next instruction if the key stored in VX isn't pressed.
          debug_printf("SKPN V%x(0x%x)\n", extractX(opcode), VX);
          if (!keys.get_key(VX & 0xF))
            PC += 2;
          break;
        }
        break;
      case 0xF:
        switch (NN) {
        case 0x07:
          // Sets VX to the value of the delay timer.
          debug_printf("LD V%x, DT\n", extractX(opcode));
          VX = delay_timer;
          break;
        case 0x0A:
          // A key press is awaited, and then stored in VX.
          debug_printf("LD V%x, K\n", extractX(opcode));
          // Clear last pressed key.
          keys.get_last_key_press();
          // Wait for new key press.
          wait_for_key = 1;
          wait_for_key_reg = extractX(opcode);
          remaining_instructions = 0;
          break;
        case 0x15:
          // Sets the delay timer to VX.
          debug_printf("LD DT, V%x(0x%x)\n", extractX(opcode), VX);
          delay_timer = VX;
          break;
        case 0x18:
          // Sets the sound timer to VX.
          debug_printf("LD ST, V%x(0x%x)\n", extractX(opcode), VX);
          sound_timer = VX;
          break;
        case 0x1E:
          // Adds VX to I. VF is set to 1 when there's overflow, 0 otherwise.
          // Setting VF is an undocumented feature used by the Spacefight 2019!
          // game.
          debug_printf("ADD I, V%x(0x%x)\n", extractX(opcode), VX);
          uint16_t result = (I + VX) & 0xfff;
          int flag = result < I;
          I = result;
          VF = flag;
          break;
        case 0x29:
          // Sets I to the location of the sprite for the character in VX.
          // Characters 0-F (in hexadecimal) are represented by a 4x5 font.
          debug_printf("LD F, V%x(0x%x)\n", extractX(opcode), VX);
          I = VX * 5;
          break;
        case 0x30:
          // Sets I to the location of the big sprite for the character in VX
          // (SCHIP-48).
          debug_printf("LD HF, V%x(0x%x)\n", extractX(opcode), VX);
          I = VX * 10 + sizeof(fonts);
          break;
        case 0x33:
          // Stores the Binary-coded decimal representation of VX, with the most
          // significant of three digits at the address in I, the middle digit
          // at I plus 1, and the least significant digit at I plus 2. (In other
          // words, take the decimal representation of VX, place the hundreds
          // digit in memory at location in I, the tens digit at location I+1,
          // and the ones digit at location I + 2.)
          debug_printf("LD B, V%x(0x%x)\n", extractX(opcode), VX);
          mem[I] = VX / 100;
          mem[I + 1] = (VX / 10) % 10;
          mem[I + 2] = VX % 10;
          break;
        case 0x55:
          // Stores V0 to VX in memory starting at address I.
          // I is set to I + X + i, see Cosmac VIP Manual.
          debug_printf("LD [I(0x%x)], V%x\n", extractX(opcode), I);
          for (unsigned i = 0; i <= extractX(opcode); i++) {
            mem[I++] = V[i];
          }
          break;
        case 0x65:
          // Fills V0 to VX with values from memory starting at address I.
          // I is set to I + X + i, see Cosmac VIP Manual.
          debug_printf("LD V%x, [I(0x%x)]\n", extractX(opcode), I);
          for (unsigned i = 0; i <= extractX(opcode); i++) {
            V[i] = mem[I++];
          }
          break;
        case 0x75:
          // Store V0 to VX (X < 8) to the HP48 flags (SCHIP-48).
          debug_printf("LD R, V%x(0x%x)\n", extractX(opcode), VX);
          for (unsigned i = 0; i <= (extractX(opcode) & 0x7); i++) {
            hp48_flags[i] = V[i];
          }
          break;
        case 0x85:
          // Load V0 to VX (X < 8) from the HP48 flags (SCHIP-48).
          debug_printf("LD V%x, R\n", extractX(opcode));
          for (unsigned i = 0; i <= (extractX(opcode) & 0x7); i++) {
            V[i] = hp48_flags[i];
          }
          break;
        }
        break;
      }
    }
    screen.flip_begin();
    do {
      select {
      case wait_for_key => keys.key_press():
        // Complete instruction.
        V[wait_for_key_reg] = keys.get_last_key_press();
        wait_for_key = 0;
        break;
      case screen.flip_end():
        if (delay_timer > 0)
          --delay_timer;
        if (sound_timer > 0)
          --sound_timer;
        break;
      }
    } while (wait_for_key);
  }
#undef VX
#undef VY
#undef N
#undef NN
#undef NNN
}

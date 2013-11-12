#include "chip8_screen.h"
#include "lcd.h"
#include "ptr_buffers.h"
#include <string.h>
#include <limits.h>
#include <xclib.h>
#define DEBUG_UNIT CHIP8_SCREEN
#include "debug_print.h"

#define SCREEN_WIDTH 128
#define SCREEN_HEIGHT 64
#define SCREEN_BPP 1
#define SCREEN_WIDTH_HALF (SCREEN_WIDTH / 2)
#define SCREEN_HEIGHT_HALF (SCREEN_HEIGHT / 2)

#define BACKGROUND_COLOR 0
#define FORGROUND_COLOR 0xffff
#define VERTICAL_SF 3
#define HORIZONTAL_SF 3
#define HORIZONTAL_OFFSET ((LCD_WIDTH - SCREEN_WIDTH * HORIZONTAL_SF) / 2)
#define VERTICAL_OFFSET ((LCD_HEIGHT - SCREEN_HEIGHT * VERTICAL_SF) / 2)

static unsigned bitrev8(unsigned value)
{
  return bitrev(value) >> 24;
}

static const uint8_t x2_lookup_table[] = {
  0b00000000,
  0b00000011,
  0b00001100,
  0b00001111,
  0b00110000,
  0b00110011,
  0b00111100,
  0b00111111,
  0b11000000,
  0b11000011,
  0b11001100,
  0b11001111,
  0b11110000,
  0b11110011,
  0b11111100,
  0b11111111,
};

extends client interface chip8_screen : {
  // Force definition in this translation unit.
  extern inline void flip(client interface chip8_screen self);
}

// TODO get rid of this.
static void movable_memset(char p[n], int c, size_t n)
{
  memset(p, c, n);
}

[[combinable]]
void chip8_screen_server(server interface chip8_screen screen,
                         client interface uint_ptr_tx_slave to_lcd,
                         client interface uint_ptr_rx from_lcd)
{
  uint32_t current_frame_32[(SCREEN_WIDTH * SCREEN_HEIGHT * SCREEN_BPP) / 32] = {0};
  uint32_t next_frame_32[(SCREEN_WIDTH * SCREEN_HEIGHT * SCREEN_BPP) / 32] = {0};
  const unsigned frame_buffer_bytes = sizeof(current_frame_32);
  uint16_t *next_frame_16 = (uint16_t *)next_frame_32;
  uint8_t *current_frame = (uint8_t *)current_frame_32;
  uint8_t *next_frame = (uint8_t *)next_frame_32;
  unsigned row0[LCD_ROW_WORDS] = {0};
  unsigned row1[LCD_ROW_WORDS] = {0};
  unsigned row2[LCD_ROW_WORDS] = {0};
  const unsigned row_bytes = sizeof(row0);
  unsigned * movable row = row0;
  unsigned * movable row1ptr = row1;
  unsigned * movable row2ptr = row2;

  // Start things off.
  to_lcd.push(move(row1ptr));
  to_lcd.push(move(row2ptr));
  unsigned row_number = 3;
  int flipped = 1;
  int flip_begin = 0;
  while (1) {
    select {
    case screen.clear():
      debug_printf("screen.clear()\n");
      memset(next_frame, 0x0, frame_buffer_bytes);
      break;
    case screen.scroll_down(unsigned n):
      debug_printf("screen.scroll_down(%u)\n", n);
      unsigned shift = n * (SCREEN_WIDTH / 8);
      memmove(next_frame + shift, next_frame, frame_buffer_bytes - shift);
      memset(next_frame, 0x0, shift);
      break;
    case screen.scroll_left4():
      debug_printf("screen.scroll_left4()\n");
      for (int j = 0; j < SCREEN_HEIGHT; j++) {
        uint32_t carry = 0;
        for (int i = SCREEN_WIDTH / 32 - 1; i >= 0; i--) {
          uint32_t &dest = next_frame_32[i + j * (SCREEN_WIDTH / 32)];
          unsigned old_value = dest;
          dest = (dest >> 4) | carry;
          carry = old_value << (32 - 4);
        }
      }
      break;
    case screen.scroll_right4():
      debug_printf("screen.scroll_right4()\n");
      for (int j = 0; j < SCREEN_HEIGHT; j++) {
        uint32_t carry = 0;
        for (int i = 0; i < SCREEN_WIDTH / 32; i++) {
          uint32_t &dest = next_frame_32[i + j * (SCREEN_WIDTH / 32)];
          unsigned old_value = dest;
          dest = (dest << 4) | carry;
          carry = old_value >> (32 - 4);
        }
      }
      break;
    case screen.draw_sprite8(uint8_t sprite[heigth], unsigned heigth, unsigned x,
                             unsigned y) -> int collision:
      debug_printf("screen.draw_sprite8(sprite, %u, %u, %u)\n", heigth, x, y);
      collision = 0;
      // If the entire sprite is off screen it will wrap around but if a
      // fragment of the sprite is off screen it will be clipped at the screen
      // edge, see Chip-8 on the COSMAC VIP.
      x = x % SCREEN_WIDTH;
      y = y % SCREEN_HEIGHT;
      if (y + heigth > SCREEN_HEIGHT)
        heigth = SCREEN_HEIGHT - y;
      for (unsigned j = 0; j < heigth; j++) {
        uint8_t sprite_val = bitrev8(sprite[j]);
        unsigned bit = x % 8;
        unsigned row_offset = x / 8;
        unsigned byte = row_offset + (y + j) * (SCREEN_WIDTH / 8);
        if (next_frame[byte] & (sprite_val << bit))
          collision = 1;
        next_frame[byte] ^= sprite_val << bit;
        if (bit != 0 && row_offset + 1 != SCREEN_WIDTH / 8) {
          if (next_frame[byte + 1] & (sprite_val >> (8 - bit)))
            collision = 1;
          next_frame[byte + 1] ^= sprite_val >> (8 - bit);
        }
      }
      break;
    case screen.draw_sprite8_x2(uint8_t sprite[heigth], unsigned heigth, unsigned x,
                                unsigned y) -> int collision:
      debug_printf("screen.draw_sprite8_x2(sprite, %u, %u, %u)\n", heigth, x,
                   y);
      collision = 0;
      // If the entire sprite is off screen it will wrap around but if a
      // fragment of the sprite is off screen it will be clipped at the screen
      // edge, see Chip-8 on the COSMAC VIP.
      x = x % SCREEN_WIDTH_HALF;
      y = y % SCREEN_HEIGHT_HALF;
      if (y + heigth > SCREEN_HEIGHT_HALF)
        heigth = SCREEN_HEIGHT_HALF - y;
      for (unsigned j = 0; j < heigth; j++) {
        uint16_t sprite_val = x2_lookup_table[bitrev8(sprite[j]) & 0xf] |
                              (x2_lookup_table[bitrev8(sprite[j]) >> 4] << 8);
        unsigned bit = (x * 2) % 16;
        unsigned row_offset = x / 8;
        unsigned offset = row_offset + (y + j) * (SCREEN_WIDTH / 8);
        if (next_frame_16[offset] & (sprite_val << bit))
          collision = 1;
        next_frame_16[offset] ^= sprite_val << bit;
        next_frame_16[offset + SCREEN_WIDTH / 16] ^= sprite_val << bit;
        if (bit != 0 && row_offset + 1 != SCREEN_WIDTH / 16) {
          if (next_frame_16[offset + 1] & (sprite_val >> (16 - bit)))
            collision = 1;
          next_frame_16[offset + 1] ^= sprite_val >> (16 - bit);
          next_frame_16[offset + SCREEN_WIDTH / 16 + 1] ^=
            sprite_val >> (16 - bit);
        }
      }
      break;
    case screen.draw_sprite16(uint8_t sprite[32], unsigned x,
                              unsigned y) -> int collision:
      debug_printf("screen.draw_sprite16(sprite, %u, %u)\n", x, y);
      collision = 0;
      // If the entire sprite is off screen it will wrap around but if a
      // fragment of the sprite is off screen it will be clipped at the screen
      // edge, see Chip-8 on the COSMAC VIP.
      x = x % SCREEN_WIDTH;
      y = y % SCREEN_HEIGHT;
      if (x < SCREEN_WIDTH && y < SCREEN_HEIGHT) {
        unsigned heigth = 16;
        if (y + heigth > SCREEN_HEIGHT)
          heigth = SCREEN_HEIGHT - y;
        for (unsigned j = 0; j < heigth; j++) {
          uint16_t sprite_val = bitrev8(sprite[2 * j]) |
                                bitrev8(sprite[2 * j + 1]) << 8;
          unsigned bit = x % 16;
          unsigned row_offset = x / 16;
          unsigned offset = row_offset + (y + j) * (SCREEN_WIDTH / 16);
          if (next_frame_16[offset] & (sprite_val << bit))
            collision = 1;
          next_frame_16[offset] ^= sprite_val << bit;
          if (bit != 0 && row_offset + 1 != SCREEN_WIDTH / 16) {
            if (next_frame_16[offset + 1] & (sprite_val >> (16 - bit)))
              collision = 1;
            next_frame_16[offset + 1] ^= sprite_val >> (16 - bit);
          }
        }
      }
      break;
    case screen.flip_begin():
      debug_printf("screen.flip_begin()\n");
      flip_begin = 1;
      break;
    case to_lcd.ready():
      //debug_printf("to_lcd.ready()\n");
      unsigned * movable next_row;
      next_row = from_lcd.pop();
      to_lcd.push(move(row));
      row = move(next_row);
      if (row_number == LCD_HEIGHT) {
        row_number = 0;
        flipped = 0;
      }
      // TODO it might be better to do the scaling in the lcd screen itself.
      if (row_number >= HORIZONTAL_OFFSET &&
          row_number < HORIZONTAL_OFFSET + SCREEN_HEIGHT * VERTICAL_SF) {
        unsigned short (& restrict dst)[SCREEN_WIDTH * HORIZONTAL_SF] =
          (unsigned short * movable)row + HORIZONTAL_OFFSET;
        unsigned y = (row_number - HORIZONTAL_OFFSET) / VERTICAL_SF;
        for (unsigned i = 0; i < SCREEN_WIDTH / 32; i++) {
          uint32_t pixels = current_frame_32[i + y * (SCREEN_WIDTH / 32)];
          for (unsigned j = 0; j < 32; j++) {
            unsigned val =
              pixels & (1 << j) ? FORGROUND_COLOR : BACKGROUND_COLOR;
            for (unsigned k = 0; k < VERTICAL_SF; k++) {
              dst[(i * 32 + j) * VERTICAL_SF + k] = val;
            }
          }
        }
      } else {
        if (!flipped && flip_begin) {
          memcpy(current_frame, next_frame, frame_buffer_bytes);
          screen.flip_end();
          flipped = 1;
          flip_begin = 0;
        }
        if (row_number >= VERTICAL_OFFSET + SCREEN_HEIGHT * VERTICAL_SF &&
            row_number < VERTICAL_OFFSET + SCREEN_HEIGHT * VERTICAL_SF + 3) {
          movable_memset((char * movable)row, 0, row_bytes);
        }
      }
      ++row_number;
      break;
    }
  }
}

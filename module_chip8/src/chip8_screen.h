#ifndef _chip8_screen_h
#define _chip8_screen_h

#include <stdint.h>

interface chip8_screen {
  void clear();
  void scroll_down(unsigned n);
  void scroll_left4();
  void scroll_right4();
  int draw_sprite8(uint8_t sprite[size], unsigned size, unsigned x, unsigned y);
  int draw_sprite8_x2(uint8_t sprite[size], unsigned size, unsigned x,
                      unsigned y);
  int draw_sprite16(uint8_t sprite[32], unsigned x, unsigned y);
  [[clears_notification]] void flip_begin();
  [[notification]] slave void flip_end();
};

extends client interface chip8_screen : {
  inline void flip(client interface chip8_screen self) {
    self.flip_begin();
    select {
    case self.flip_end():
      break;
    }
  }
}

interface uint_ptr_tx_slave;
interface uint_ptr_rx;

[[combinable]]
void chip8_screen_server(server interface chip8_screen c,
                         client interface uint_ptr_tx_slave to_lcd,
                         client interface uint_ptr_rx from_lcd);

#endif /* _chip8_screen_h */

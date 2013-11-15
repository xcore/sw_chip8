#include "ps2_keyboard.h"
#include "ps2.h"
#include <print.h>

extends client interface ps2_keyboard_callback : {
  static void key_down(client interface ps2_keyboard_callback c, uint8_t data)
  {
    c.event(PS2_KEY_DOWN, data);
  }
  static void key_up(client interface ps2_keyboard_callback c, uint8_t data)
  {
    c.event(PS2_KEY_UP, data);
  }
  static void extended_key_down(client interface ps2_keyboard_callback c,
                                uint8_t data)
  {
    c.event(PS2_EXTENDED_KEY_DOWN, data);
  }
  static void extended_key_up(client interface ps2_keyboard_callback c,
                              uint8_t data)
  {
    c.event(PS2_EXTENDED_KEY_UP, data);
  }
}

[[distributable]]
void ps2_keyboard(server interface ps2_callback ps2,
                  client interface ps2_keyboard_callback c)
{
  enum state {
    DOWN,
    UP,
    EXTENDED_DOWN,
    EXTENDED_UP
  } state = DOWN;
  while (1) {
    select {
    case ps2.data(uint8_t data):
      switch (state) {
      case DOWN:
        if (data == 0xe0) {
          state = EXTENDED_DOWN;
        } else if (data == 0xf0) {
          state = UP;
        } else {
          c.key_down(data);
        }
        break;
      case UP:
        c.key_up(data);
        state = DOWN;
        break;
      case EXTENDED_DOWN:
        if (data == 0xf0) {
          state = EXTENDED_UP;
        } else {
          c.extended_key_down(data);
          state = DOWN;
        }
        break;
      case EXTENDED_UP:
        c.extended_key_up(data);
        state = DOWN;
        break;
      }
      break;
    }
  }
}

void ps2_keyboard_print_event(enum ps2_keyboard_event type, uint8_t data)
{
  // TODO print key name.
  switch (type) {
  case PS2_KEY_DOWN:
    printstr("Key press 0x");
    break;
  case PS2_EXTENDED_KEY_DOWN:
    printstr("Extended key press 0x");
    break;
  case PS2_KEY_UP:
    printstr("Key release 0x");
    break;
  case PS2_EXTENDED_KEY_UP:
    printstr("Extended key release 0x");
    break;
  }
  printhexln(data);
}

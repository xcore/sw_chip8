#include "chip8_ps2_keyboard.h"
#include "ps2_keyboard.h"
#include "chip8_keys.h"
#define DEBUG_UNIT CHIP8_KEYS
#include "debug_print.h"
#include "xassert.h"

static int get_key_mapping(int extended, uint8_t data)
{
  if (extended) {
    return -1;
  }
  switch (data) {
  case PS2_KEYBOARD_SCANCODE_1: return 0x1;
  case PS2_KEYBOARD_SCANCODE_2: return 0x2;
  case PS2_KEYBOARD_SCANCODE_3: return 0x3;
  case PS2_KEYBOARD_SCANCODE_4: return 0xc;
  case PS2_KEYBOARD_SCANCODE_Q: return 0x4;
  case PS2_KEYBOARD_SCANCODE_W: return 0x5;
  case PS2_KEYBOARD_SCANCODE_E: return 0x6;
  case PS2_KEYBOARD_SCANCODE_R: return 0xd;
  case PS2_KEYBOARD_SCANCODE_A: return 0x7;
  case PS2_KEYBOARD_SCANCODE_S: return 0x8;
  case PS2_KEYBOARD_SCANCODE_D: return 0x9;
  case PS2_KEYBOARD_SCANCODE_F: return 0xe;
  case PS2_KEYBOARD_SCANCODE_Z: return 0xa;
  case PS2_KEYBOARD_SCANCODE_X: return 0x0;
  case PS2_KEYBOARD_SCANCODE_C: return 0xb;
  case PS2_KEYBOARD_SCANCODE_V: return 0xf;
  }
  return -1;
}

static int is_key_down(enum ps2_keyboard_event type)
{
  switch (type) {
  default: unreachable();
    return 0; // Silence compiler warning.
  case PS2_KEY_DOWN:
  case PS2_EXTENDED_KEY_DOWN:
    return 1;
  case PS2_KEY_UP:
  case PS2_EXTENDED_KEY_UP:
    return 0;
  }
}

static int is_extended(enum ps2_keyboard_event type)
{
  switch (type) {
  default: unreachable();
    return 0; // Silence compiler warning.
  case PS2_EXTENDED_KEY_DOWN:
  case PS2_EXTENDED_KEY_UP:
    return 1;
  case PS2_KEY_DOWN:
  case PS2_KEY_UP:
    return 0;
  }
}

[[distributable]]
void chip8_ps2_keyboard(server interface chip8_keys keys,
                        server interface ps2_keyboard_callback ps2_keyboard)
{
  char values[CHIP8_NUM_KEYS] = {0};
  int last_key_press = -1;
  while (1) {
    select {
    case keys.get_key(unsigned num) -> int value:
      debug_printf("keys.get_key(%u)\n", num);
      value = values[num];
      break;
    case keys.get_last_key_press() -> int pressed:
      debug_printf("keys.get_last_key_press()\n");
      pressed = last_key_press;
      break;
    case ps2_keyboard.event(enum ps2_keyboard_event type, uint8_t data):
      int extended = is_extended(type);
      int key = get_key_mapping(extended, data);
      if (key >= 0) {
        int value = is_key_down(type);
        debug_printf("key %x=%d\n", key, value);
        values[key] = value;
        if (value) {
          last_key_press = key;
          keys.key_press();
        }
      }
      break;
    }
  }
}

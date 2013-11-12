#include "chip8_keys.h"
#include "gc_controller.h"
#define DEBUG_UNIT CHIP8_KEYS
#include "debug_print.h"
#include "xassert.h"

#define POSITIVE_AXIS_THRESHOLD (128 + 75)
#define NEGATIVE_AXIS_THRESHOLD (128 - 75)

enum key_mapping_type {
  MAPPING_BUTTON,
  MAPPING_POSITIVE_AXIS,
  MAPPING_NEGATIVE_AXIS,
  MAPPING_UNMAPPED
};

typedef struct key_mapping_t {
  enum key_mapping_type type;
  unsigned value;
} key_mapping_t;

static key_mapping_t mappings[] = {
  { MAPPING_UNMAPPED }, // 0
  { MAPPING_BUTTON, GC_CONTROLLER_B }, // 1
  { MAPPING_POSITIVE_AXIS, GC_CONTROLLER_AXIS_Y }, // 2
  { MAPPING_BUTTON, GC_CONTROLLER_X }, // 3
  { MAPPING_NEGATIVE_AXIS, GC_CONTROLLER_AXIS_X}, // 4
  { MAPPING_BUTTON, GC_CONTROLLER_A }, // 5
  { MAPPING_POSITIVE_AXIS, GC_CONTROLLER_AXIS_X}, // 6
  { MAPPING_BUTTON, GC_CONTROLLER_Y }, // 7
  { MAPPING_NEGATIVE_AXIS, GC_CONTROLLER_AXIS_Y }, // 8
  { MAPPING_BUTTON, GC_CONTROLLER_Z }, // 9
  { MAPPING_UNMAPPED }, // A
  { MAPPING_UNMAPPED }, // B
  { MAPPING_UNMAPPED }, // C
  { MAPPING_UNMAPPED }, // D
  { MAPPING_UNMAPPED }, // E
  { MAPPING_UNMAPPED }, // F
};

[[distributable]]
void chip8_gamecube_controller(server interface chip8_keys user,
                               server interface gc_controller_tx controller)
{
  char keys[CHIP8_NUM_KEYS] = {0};
  int last_key_press = -1;
  while (1) {
    select {
    case user.get_key(unsigned num) -> int value:
      debug_printf("user.get_key(%u)\n", num);
      value = keys[num];
      break;
    case user.get_last_key_press() -> int pressed:
      debug_printf("user.get_last_key_press()\n");
      pressed = last_key_press;
      break;
    case controller.push(gc_controller_state_t data):
      for (unsigned i = 0; i < CHIP8_NUM_KEYS; i++) {
        key_mapping_t mapping = mappings[i];
        int key_value;
        switch (mapping.type) {
        case MAPPING_UNMAPPED:
          continue;
        case MAPPING_BUTTON:
          key_value = gc_controller_get_button(data, mapping.value);
          break;
        case MAPPING_POSITIVE_AXIS:
          unsigned axis_value = gc_controller_get_axis(data, mapping.value);
          key_value = axis_value >= POSITIVE_AXIS_THRESHOLD;
          break;
        case MAPPING_NEGATIVE_AXIS:
          unsigned axis_value = gc_controller_get_axis(data, mapping.value);
          key_value = axis_value <= NEGATIVE_AXIS_THRESHOLD;
          break;
        }
        if (key_value == keys[i])
          continue;
        debug_printf("key %x = %d\n", i, key_value);
        if (key_value) {
          last_key_press = i;
          user.key_press();
        }
        keys[i] = key_value;
      }
      break;
    }
  }
}

#include "chip8_menu.h"
#include "chip8_image_bundle.h"
#include "text_display.h"
#include "chip8_keys.h"
#include "xassert.h"
#include <string.h>
#include <xs1.h>

#define MIN(x, y) ((x) < (y)) ? (x) : (y)

static void
draw_menu(const struct chip8_image_bundle_entry_list_t &entry_list,
          client interface text_display display,
          unsigned offset, unsigned selected)
{
  unsigned n = entry_list.num_entries;
  chip8_image_bundle_entry_t *entries = entry_list.entries;
  char *strings = entry_list.strings;
  char buf[TEXT_DISPLAY_COLUMNS];
  buf[1] = ' ';
  select {
  case display.vblank():
    break;
  }
  display.clear();
  unsigned end = MIN(offset + TEXT_DISPLAY_ROWS - 1, n);
  for (unsigned i = offset; i < end; i++) {
    const char *name = &strings[entries[i].name_offset];
    unsigned name_length = strnlen(name, TEXT_DISPLAY_COLUMNS - 3);
    buf[0] = i == selected ? '>' : ' ';
    memcpy(&buf[2], name, name_length);
    buf[2 + name_length] = '\n';
    display.write(buf, 3 + name_length);
  }
  display.clear_vblank();
}

unsigned
chip8_menu(const struct chip8_image_bundle_entry_list_t &entry_list,
           client interface text_display display,
           client interface chip8_keys keys)
{
  unsigned offset = 0;
  unsigned selected = 0;
  draw_menu(entry_list, display, offset, selected);
  timer t;
  unsigned time;
  int pressed = -1;
  const unsigned up_key = 2;
  const unsigned down_key = 8;
  const unsigned select_key = 5;
  const unsigned repeat_ticks = 100000;
  while (1) {
    select {
    case (pressed >= 0) => t when timerafter(time + repeat_ticks) :> void:
      if (keys.get_key(pressed)) {
        time += repeat_ticks;
        if (pressed == up_key) {
          if (selected > 0) {
            selected--;
            if (selected == offset && offset > 0) {
              offset--;
            }
            draw_menu(entry_list, display, offset, selected);
          }
        } else {
          assert(pressed == down_key);
          if (selected + 1 < entry_list.num_entries) {
            selected++;
            if (selected == offset + TEXT_DISPLAY_ROWS - 2) {
              offset++;
            }
            draw_menu(entry_list, display, offset, selected);
          }
        }
      } else {
        pressed = -1;
      }
      break;
    case keys.key_press():
      int last_press = keys.get_last_key_press();
      if (last_press == up_key || last_press == down_key) {
        pressed = last_press;
        t :> time;
      } else if (last_press == select_key) {
        return selected;
      }
      break;
    }
  }
  // Silence compiler
  return 0;
}

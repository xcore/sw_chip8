#include <platform.h>
#include <string.h>
#include <stdlib.h>
#include <print.h>
#include "chip8_cpu.h"
#include "chip8_screen.h"
#include "chip8_keys.h"
#include "chip8_ps2_keyboard.h"
#include "lcd.h"
#include "syscall.h"
#include "ps2.h"
#include "ps2_keyboard.h"
#include "chip8_menu.h"
#include "text_display.h"
#include "text_display_font.h"

lcd_ports ports = {
  XS1_PORT_1G, /* clk */
  XS1_PORT_1F, /* de */
  XS1_PORT_16A, /* data */
  XS1_PORT_1B, /* hsync */
  XS1_PORT_1C, /* vsync */
  XS1_CLKBLK_1
};

ps2_ports_t ps2_ports = {
  XS1_PORT_1A, /* clk */
  XS1_PORT_1L /* data */
};

#define ARRAY_SIZE(x) (sizeof(x) / sizeof(x[0]))

[[distributable]]
void chip8_callbacks_server(server interface chip8_callbacks callbacks,
                            client interface chip8_image_reader image_reader,
                            const chip8_image_bundle_entry_t &image)
{
  while (1) {
    select {
    case callbacks.load_image(uint8_t mem[CHIP8_MAX_IMAGE_SIZE]):
      uint8_t buffer[CHIP8_MAX_IMAGE_SIZE];
      int image_size = image_reader.get_image(buffer, image);
      memcpy(mem, buffer, image_size);
      break;
    case callbacks.exit():
      _Exit(0);
      break;
    }
  }
}

#define MAX_ENTRIES 100
#define MAX_STRING_TABLE_SIZE 2000

void
chip8_with_menu(client interface chip8_image_reader image_reader,
                client interface chip8_keys keys,
                client interface uint_ptr_tx_slave to_lcd,
                client interface uint_ptr_rx from_lcd)
{
  while (1) {
    chip8_image_bundle_entry_t selected_image;
    {
      interface text_display display;
      chip8_image_bundle_entry_t entries[MAX_ENTRIES];
      char strings[MAX_STRING_TABLE_SIZE];
      int n = image_reader.get_entries(entries, MAX_ENTRIES, strings,
                                       MAX_STRING_TABLE_SIZE);
      int selected;
      par {
        {
          selected = chip8_menu(entries, n, strings, display, keys);
          display.shutdown();
        }
        text_display_server(display, to_lcd, from_lcd,
                            text_display_default_font);
      }
      selected_image = entries[selected];
    }
    {
      interface chip8_screen screen;
      interface chip8_callbacks chip8_callbacks;
      par {
        chip8_screen_server(screen, to_lcd, from_lcd);
        chip8_cpu(keys, screen, chip8_callbacks);
        [[distribute]] chip8_callbacks_server(chip8_callbacks, image_reader,
                                              selected_image);
      }
    }
  }
}

int main() {
  interface uint_ptr_tx_slave to_buffer;
  interface uint_ptr_rx to_lcd;
  interface uint_ptr_tx from_lcd;
  interface uint_ptr_rx from_buffer;
  interface chip8_keys keys;
  interface ps2_callback ps2_callback;
  interface ps2_keyboard_callback ps2_keyboard_callback;
  interface chip8_image_reader image_reader;

  par {
    [[distribute]] chip8_image_reader_file(image_reader, "images.bin");
    [[distribute]] uint_ptr_buffer_tx_slave(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    chip8_with_menu(image_reader, keys, to_buffer, from_buffer);
    ps2_server(ps2_ports, ps2_callback);
    [[distribute]] ps2_keyboard(ps2_callback, ps2_keyboard_callback);
    [[distribute]] chip8_ps2_keyboard(keys, ps2_keyboard_callback);
  }
  return 0;
}

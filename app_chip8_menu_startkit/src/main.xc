#include <platform.h>
#include <string.h>
#include <stdlib.h>
#include <print.h>
#include "chip8_cpu.h"
#include "chip8_screen.h"
#include "chip8_keys.h"
#include "chip8_gamecube_controller.h"
#include "chip8_image_bundle.h"
#include "lcd.h"
#include "syscall.h"
#include "chip8_menu.h"
#include "chip8_image_bundle.h"
#include "text_display.h"
#include "text_display_font.h"
#include "gc_controller.h"
#include "xassert.h"

#define GC_CONTROLLER_POLL_INTERVAL (XS1_TIMER_MHZ * 12 * 1000)

lcd_ports ports = {
  XS1_PORT_1I, /* clk */
  XS1_PORT_1L, /* de */
  XS1_PORT_8B, /* data[0:7] */
  XS1_PORT_8D, /* data[8:11] */
  XS1_PORT_4E, /* data[12:15] */
  XS1_PORT_1J, /* hsync */
  XS1_PORT_1K, /* vsync */
  XS1_CLKBLK_1
};

port gc_controller_port = XS1_PORT_1C;

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

#define IMAGES_BUFFER_SIZE 4000

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
      chip8_image_bundle_entry_list_t entry_list;
      char buffer[IMAGES_BUFFER_SIZE];
      char * movable buffer_ptr = buffer;
      if (image_reader.get_entries(&entry_list, move(buffer_ptr),
                                   IMAGES_BUFFER_SIZE) < 0) {
        fail("failed to read images");
      }
      int selected;
      par {
        {
          selected =
           chip8_menu(entry_list, display, keys);
          display.shutdown();
        }
        text_display_server(display, to_lcd, from_lcd,
                            text_display_default_font);
      }
      selected_image = entry_list.entries[selected];
      buffer_ptr = chip8_image_reader_recycle_entry_list(entry_list);
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
  interface gc_controller_tx gc_controller;
  interface chip8_image_reader image_reader;

  par {
    [[distribute]] chip8_image_reader_file(image_reader, "images.bin");
    [[distribute]] uint_ptr_buffer_tx_slave(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    chip8_with_menu(image_reader, keys, to_buffer, from_buffer);
    gc_controller_poller(gc_controller_port, gc_controller,
                         GC_CONTROLLER_POLL_INTERVAL);
    [[distribute]] chip8_gamecube_controller(keys, gc_controller);
  }
  return 0;
}

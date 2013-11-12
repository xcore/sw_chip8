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

[[distributable]]
 void chip8_callbacks_server(server interface chip8_callbacks callbacks)
{
  while (1) {
    select {
    case callbacks.load_image(uint8_t mem[CHIP8_MAX_IMAGE_SIZE]):
      uint8_t buffer[CHIP8_MAX_IMAGE_SIZE];
      int fd = _open("image.bin", O_RDONLY | O_BINARY, 0);
      if (fd < 0) {
        printstr("Error opening image.bin\n");
        _Exit(1);
      }
      int num_bytes = _lseek(fd, 0, SEEK_END);
      if (num_bytes < 0) {
        printstr("_lseek() failed\n");
        _Exit(1);
      }
      if (_lseek(fd, 0, SEEK_SET) < 0) {
        printstr("_lseek() failed\n");
        _Exit(1);
      }
      if (num_bytes > CHIP8_MAX_IMAGE_SIZE) {
        printstr("image too large\n");
        _Exit(1);
      }
      int bytes_read = _read(fd, buffer, num_bytes);
      if (bytes_read < num_bytes) {
        printstr("_read() failed\n");
        _Exit(1);
      }
      _close(fd);
      memcpy(mem, buffer, num_bytes);
      break;
    case callbacks.exit():
      _Exit(0);
      break;
    }
  }
}

int main() {
  interface uint_ptr_tx_slave to_buffer;
  interface uint_ptr_rx to_lcd;
  interface uint_ptr_tx from_lcd;
  interface uint_ptr_rx from_buffer;
  interface chip8_screen screen;
  interface chip8_keys keys;
  interface chip8_callbacks chip8_callbacks;
  interface ps2_callback ps2_callback;
  interface ps2_keyboard_callback ps2_keyboard_callback;
  par {
    [[distribute]] uint_ptr_buffer_tx_slave(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    chip8_screen_server(screen, to_buffer, from_buffer);
    ps2_server(ps2_ports, ps2_callback);
    chip8_cpu(keys, screen, chip8_callbacks);
    [[distribute]] ps2_keyboard(ps2_callback, ps2_keyboard_callback);
    [[distribute]] chip8_ps2_keyboard(keys, ps2_keyboard_callback);
    [[distribute]] chip8_callbacks_server(chip8_callbacks);
  }
  return 0;
}

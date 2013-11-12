#include <platform.h>
#include <string.h>
#include <stdlib.h>
#include <print.h>
#include "chip8_cpu.h"
#include "chip8_screen.h"
#include "chip8_keys.h"
#include "chip8_gamecube_controller.h"
#include "lcd.h"
#include "syscall.h"
#include "gc_controller.h"
#include "xscope.h"

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

void xscope_user_init(void)
{
  xscope_register(0, 0, "", 0, "");
  xscope_config_io(XSCOPE_IO_BASIC);
}

int main() {
  interface uint_ptr_tx_slave to_buffer;
  interface uint_ptr_rx to_lcd;
  interface uint_ptr_tx from_lcd;
  interface uint_ptr_rx from_buffer;
  interface chip8_screen screen;
  interface chip8_keys keys;
  interface chip8_callbacks chip8_callbacks;
  interface gc_controller_tx gc_controller;
  par {
    [[distribute]] uint_ptr_buffer_tx_slave(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    chip8_screen_server(screen, to_buffer, from_buffer);
    gc_controller_poller(gc_controller_port, gc_controller,
                         GC_CONTROLLER_POLL_INTERVAL);
    chip8_cpu(keys, screen, chip8_callbacks);
    [[distribute]] chip8_gamecube_controller(keys, gc_controller);
    [[distribute]] chip8_callbacks_server(chip8_callbacks);
  }
  return 0;
}

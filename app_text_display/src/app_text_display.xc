#include <platform.h>
#include <string.h>
#include <stdio.h>
#include "lcd.h"
#include "text_display.h"
#include "text_display_font.h"
#include "timer.h"

lcd_ports ports = {
  XS1_PORT_1G, /* clk */
  XS1_PORT_1F, /* de */
  XS1_PORT_16A, /* data */
  XS1_PORT_1B, /* hsync */
  XS1_PORT_1C, /* vsync */
  XS1_CLKBLK_1
};

void demo(client interface text_display display)
{
  display.printstr("Hello world!\n");
}

int main() {
  interface uint_ptr_tx_slave to_buffer;
  interface uint_ptr_rx to_lcd;
  interface uint_ptr_tx from_lcd;
  interface uint_ptr_rx from_buffer;
  interface text_display display;
  par {
    [[distribute]] uint_ptr_buffer_tx_slave(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    text_display_server(display, to_buffer, from_buffer,
                        text_display_default_font);
    demo(display);
  }
  return 0;
}

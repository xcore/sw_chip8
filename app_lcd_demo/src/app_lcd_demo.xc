#include <platform.h>
#include <string.h>
#include "lcd.h"
#include "sprite.h"

lcd_ports ports = {
  XS1_PORT_1I,
  XS1_PORT_1L,
  XS1_PORT_8B,
  XS1_PORT_8D,
  XS1_PORT_4E,
  XS1_PORT_1J,
  XS1_PORT_1K,
  XS1_CLKBLK_1
};

static inline void add(unsigned x, unsigned y, unsigned line,
                       unsigned buffer[]) {
  if (line >= x && line < x + SPRITE_HEIGHT_PX)
    memcpy(&buffer[y], &logo[(line - x) * SPRITE_WIDTH_WORDS],
           SPRITE_WIDTH_WORDS * sizeof(int));
}

static inline void sub(unsigned x, unsigned y, unsigned line,
                       unsigned buffer[]) {
  if (line >= x && line < x + SPRITE_HEIGHT_PX)
    for (unsigned i = y; i < y + SPRITE_WIDTH_WORDS; i++)
      buffer[i] = BACK_COLOUR;
}

void demo(client interface uint_ptr_tx tx, client interface uint_ptr_rx rx) {
  unsigned buffer0[LCD_ROW_WORDS];
  unsigned buffer1[LCD_ROW_WORDS];
  for (unsigned i = 0; i < LCD_ROW_WORDS; i++)
    buffer0[i] = buffer1[i] = BACK_COLOUR;
  unsigned * movable buffer = buffer0;
  unsigned * movable next_buffer = buffer1;
  // Start things off.
  tx.push(move(buffer));
  buffer = move(next_buffer);
  for (unsigned line = 1; line < LCD_HEIGHT; line++) {
    tx.push(move(buffer));
    buffer = rx.pop();
  }

  unsigned update = 0;
  int x = 20, y = 0, vx = 1, vy = 2;

  while (1) {
    for (unsigned line = 0; line < LCD_HEIGHT; line++) {
      add(x, y, line, buffer);
      tx.push(move(buffer));
      buffer = rx.pop();
      sub(x, y, line - 1, buffer);
    }
    if (update) {
      x += vx;
      y += vy;
      if (y <= 0) {
        vy = -vy;
        y = -y;
      }
      if (y + SPRITE_WIDTH_WORDS >= LCD_ROW_WORDS) {
        vy = -vy;
        y = 2 * (LCD_ROW_WORDS - SPRITE_WIDTH_WORDS) - y - 1;
      }
      if (x <= 0) {
        vx = -vx;
        x = -x;
      }
      if (x + SPRITE_HEIGHT_PX >= LCD_HEIGHT) {
        vx = -vx;
        x = 2 * (LCD_ROW_WORDS - SPRITE_WIDTH_WORDS) - x - 1;
      }
    }
    update = !update;
  }
}

int main() {
  interface uint_ptr_tx to_buffer;
  interface uint_ptr_rx to_lcd;
  interface uint_ptr_tx from_lcd;
  interface uint_ptr_rx from_buffer;
  par {
    [[distribute]] uint_ptr_buffer(to_buffer, to_lcd);
    lcd_server(to_lcd, from_lcd, ports);
    [[distribute]] uint_ptr_buffer(from_lcd, from_buffer);
    demo(to_buffer, from_buffer);
  }
  return 0;
}

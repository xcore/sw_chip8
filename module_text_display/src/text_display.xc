#include "text_display.h"
#include "lcd.h"
#include "ptr_buffers.h"
#include "xassert.h"
#include <string.h>
#include <stdint.h>
#include <print.h>

#define SCREEN_SIZE (TEXT_DISPLAY_ROWS * TEXT_DISPLAY_COLUMNS)

static void
scroll(unsigned char buffer[SCREEN_SIZE], unsigned &pixel_row_offset,
       unsigned &text_offset)
{
  // Clear the first row
  memset(&buffer[text_offset], ' ', TEXT_DISPLAY_COLUMNS);
  // Move offset so first row is now the last row.
  text_offset += TEXT_DISPLAY_COLUMNS;
  if (text_offset == SCREEN_SIZE)
    text_offset -= SCREEN_SIZE;
  pixel_row_offset += 8;
  if (pixel_row_offset >= LCD_HEIGHT)
    pixel_row_offset -= LCD_HEIGHT;
}

// TODO get rid of this.
static void movable_memset(char p[n], int c, size_t n)
{
  memset(p, c, n);
}

#if TEXT_DISPLAY_SUPPORT_SHUTDOWN
static void
put_back_row(unsigned * movable row, unsigned * movable rows[3],
             intptr_t row_addresses[3])
{
  for (unsigned i = 0; i < 3; i++) {
    if (row == row_addresses[i]) {
      rows[i] = move(row);
      return;
    }
  }
}
#endif

[[combinable]]
void text_display_server(server interface text_display display,
                         client interface uint_ptr_tx_slave to_lcd,
                         client interface uint_ptr_rx from_lcd,
                         const char font[128][8])
{
  unsigned char buffer[SCREEN_SIZE];
  memset(buffer, ' ', SCREEN_SIZE);
  unsigned row0[LCD_ROW_WORDS] = {0};
  unsigned row1[LCD_ROW_WORDS] = {0};
  unsigned row2[LCD_ROW_WORDS] = {0};
  unsigned * movable rows[] = { row0, row1, row2 };
  unsigned * movable row;
  unsigned pixel_row_number = 3;
  unsigned cursor = 0;
  unsigned pixel_row_offset = 0;
  unsigned text_offset = 0;
  const unsigned tab_spaces = 8;
#if TEXT_DISPLAY_SUPPORT_SHUTDOWN
  int shutting_down = 0;
  intptr_t row_addresses[3];
  for (unsigned i = 0; i < 3; i++) {
    row_addresses[i] = (intptr_t)rows[i];
  }
#endif
  row = move(rows[0]);
  // Start things off.
  to_lcd.push(move(rows[1]));
  to_lcd.push(move(rows[2]));
  while (1) {
    select {
    case display.clear():
      memset(buffer, ' ', SCREEN_SIZE);
      cursor = 0;
      pixel_row_offset = 0;
      text_offset = 0;
      break;
    case display.write(const char s[n], unsigned n):
      for (unsigned i = 0; i < n; i++) {
        char c = s[i];
        if ((unsigned char)c >= 128) {
          c = ' ';
        }
        switch (c) {
        default:
          buffer[cursor++] = c;
          if (cursor == SCREEN_SIZE) {
            cursor = 0;
          }
          if (cursor == text_offset) {
            scroll(buffer, pixel_row_offset, text_offset);
          }
          break;
        case '\n':
          unsigned new_cursor =
            (cursor / TEXT_DISPLAY_COLUMNS) * TEXT_DISPLAY_COLUMNS;
          new_cursor += TEXT_DISPLAY_COLUMNS;
          memset(&buffer[cursor], ' ', new_cursor - cursor);
          if (new_cursor == SCREEN_SIZE)
            new_cursor = 0;
          if (new_cursor == text_offset)
            scroll(buffer, pixel_row_offset, text_offset);
          cursor = new_cursor;
          break;
        case '\r':
          cursor = (cursor / TEXT_DISPLAY_COLUMNS) * TEXT_DISPLAY_COLUMNS;
          break;
        case '\t':
          unsigned spaces =
            ((cursor % TEXT_DISPLAY_COLUMNS) / tab_spaces) * tab_spaces +
            tab_spaces;
          for (unsigned i = 0; i < spaces; i++) {
            buffer[cursor++] = c;
            if (cursor == SCREEN_SIZE) {
              cursor = 0;
            }
            if (cursor == text_offset) {
              scroll(buffer, pixel_row_offset, text_offset);
            }
          }
          break;
        }
      }
      break;
#if TEXT_DISPLAY_SUPPORT_SHUTDOWN
    case display.shutdown():
      shutting_down = 1;
      break;
#endif
#if TEXT_DISPLAY_SUPPORT_VBLANK_NOTIFY
    case display.clear_vblank():
      break;
#endif
    case to_lcd.ready():
      unsigned * movable next_row;
      next_row = from_lcd.pop();
      to_lcd.push(move(row));
      row = move(next_row);
      unsigned offset_pixel_row_number = (pixel_row_number + pixel_row_offset);
      if (offset_pixel_row_number >= LCD_HEIGHT)
        offset_pixel_row_number -= LCD_HEIGHT;
      unsigned text_row = offset_pixel_row_number / 8;
      if (text_row < TEXT_DISPLAY_ROWS) {
        unsigned font_row = offset_pixel_row_number % 8;
        {
          unsigned short (& restrict dst)[TEXT_DISPLAY_COLUMNS * 8] =
            (unsigned short * movable)row;
          for (unsigned i = 0; i < TEXT_DISPLAY_COLUMNS; i++) {
            unsigned offset = TEXT_DISPLAY_COLUMNS * text_row + i;
            char val = font[(unsigned char)buffer[offset]][font_row];
            for (unsigned j = 0; j < 8; j++) {
              dst[i * 8 + j] = val & (1 << j) ? 0xffff : 0x0000;
            }
          }
        }
      } else if (text_row < TEXT_DISPLAY_ROWS + 3) {
        movable_memset((char * movable)row, 0, TEXT_DISPLAY_COLUMNS * 8);
      }
      ++pixel_row_number;
      if (pixel_row_number == LCD_HEIGHT) {
#if TEXT_DISPLAY_SUPPORT_SHUTDOWN
        if (shutting_down) {
          put_back_row(move(row), rows, row_addresses);
          put_back_row(from_lcd.pop(), rows, row_addresses);
          put_back_row(from_lcd.pop(), rows, row_addresses);
          return;
        }
#endif
#if TEXT_DISPLAY_SUPPORT_VBLANK_NOTIFY
        display.vblank();
#endif
        pixel_row_number = 0;
      }
      break;
    }
  }
}

extends client interface text_display : {
  void printstr(client interface text_display self, const char s[]) {
    unsigned len = strlen(s);
    self.write(s, len);
  }
}

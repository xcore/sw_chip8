#ifndef _text_display_h_
#define _text_display_h_

#include "lcd.h"

#ifdef __text_display_conf_h_exists__
#include "text_display_conf.h"
#endif

#ifndef TEXT_DISPLAY_SUPPORT_SHUTDOWN
#define TEXT_DISPLAY_SUPPORT_SHUTDOWN 0
#endif

#ifndef TEXT_DISPLAY_SUPPORT_VBLANK_NOTIFY
#define TEXT_DISPLAY_SUPPORT_VBLANK_NOTIFY 0
#endif

#ifndef TEXT_DISPLAY_ROWS
#define TEXT_DISPLAY_ROWS (LCD_HEIGHT / 8)
#endif

#ifndef TEXT_DISPLAY_COLUMNS
#define TEXT_DISPLAY_COLUMNS (LCD_WIDTH / 8)
#endif

interface text_display {
  void clear();
  void write(const char s[n], unsigned n);
#if TEXT_DISPLAY_SUPPORT_SHUTDOWN
  void shutdown();
#endif
#if TEXT_DISPLAY_SUPPORT_VBLANK_NOTIFY
  [[notification]] slave void vblank();
  [[clears_notification]] void clear_vblank();
#endif
};

extends client interface text_display : {
  void printstr(client interface text_display self, const char s[]);
}

interface uint_ptr_tx_slave;
interface uint_ptr_rx;

[[combinable]]
void text_display_server(server interface text_display display,
                         client interface uint_ptr_tx_slave to_lcd,
                         client interface uint_ptr_rx from_lcd,
                         const char font[128][8]);

#endif /* _text_display_h_ */

#ifndef _chip8_menu_h_
#define _chip8_menu_h_

#include "chip8_image_bundle.h"

interface text_display;
interface chip8_keys;

unsigned
chip8_menu(chip8_image_bundle_entry_t entries[n], unsigned n,
           const char strings[],
           client interface text_display display,
           client interface chip8_keys keys);

#endif /* _chip8_menu_h_ */

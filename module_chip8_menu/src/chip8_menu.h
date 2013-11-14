#ifndef _chip8_menu_h_
#define _chip8_menu_h_

interface text_display;
interface chip8_keys;

struct chip8_image_bundle_entry_list_t;

unsigned
chip8_menu(const struct chip8_image_bundle_entry_list_t &entry_list,
           client interface text_display display,
           client interface chip8_keys keys);

#endif /* _chip8_menu_h_ */

#ifndef _chip8_gamecube_controller_h_
#define _chip8_gamecube_controller_h_

interface chip8_keys;
interface ps2_keyboard_callback;

[[distributable]]
void chip8_ps2_keyboard(server interface chip8_keys keys,
                        server interface ps2_keyboard_callback keyboard);

#endif

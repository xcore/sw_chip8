#ifndef _chip8_gamecube_controller_h_

interface chip8_keys;
interface gc_controller_tx;

[[distributable]]
void chip8_gamecube_controller(server interface chip8_keys iface,
                               server interface gc_controller_tx controller);

#endif

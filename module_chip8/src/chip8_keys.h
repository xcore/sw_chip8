#ifndef _chip8_keys_h
#define _chip8_keys_h

#define CHIP8_NUM_KEYS 16

interface gc_controller_tx;

interface chip8_keys {
  /// Return the value of the specified key.
  int get_key(unsigned num);
  /// Returns the ordinal of the last key pressed, or -1 if no key has been
  /// pressed.
  [[clears_notification]] int get_last_key_press();
  [[notification]] slave void key_press();
};

#endif /* _chip8_keys_h */

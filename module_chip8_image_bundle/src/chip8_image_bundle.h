#ifndef _chip8_image_bundle_h_
#define _chip8_image_bundle_h_

#include <stdint.h>

typedef struct chip8_image_bundle_entry_t {
  uint32_t name_offset;
  uint32_t data_offset;
  uint32_t data_size;
} chip8_image_bundle_entry_t;

interface chip8_image_reader {
  int get_entries(chip8_image_bundle_entry_t *entries, unsigned max_entries,
                  char *strings, unsigned string_table_size);
  int get_image(char *dst, const chip8_image_bundle_entry_t entry);
  void close();
};

[[distributable]] void
chip8_image_reader_file(server interface chip8_image_reader reader,
                        char filename[]);

#endif /* _chip8_image_bundle_h_ */

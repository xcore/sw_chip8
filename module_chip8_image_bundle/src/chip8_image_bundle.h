#ifndef _chip8_image_bundle_h_
#define _chip8_image_bundle_h_

#include <stdint.h>

typedef struct chip8_image_bundle_entry_t {
  uint32_t name_offset;
  uint32_t data_offset;
  uint32_t data_size;
} chip8_image_bundle_entry_t;

typedef struct chip8_image_bundle_entry_list_t {
  unsigned num_entries;
  chip8_image_bundle_entry_t * movable entries;
  char * movable strings;
} chip8_image_bundle_entry_list_t;

interface chip8_image_reader {
  int get_entries(chip8_image_bundle_entry_list_t *entry_list,
                  char * movable buffer, unsigned buffer_size);
  int get_image(char *dst, const chip8_image_bundle_entry_t entry);
  void close();
};

char * movable
chip8_image_reader_recycle_entry_list(chip8_image_bundle_entry_list_t &el);

[[distributable]] void
chip8_image_reader_file(server interface chip8_image_reader reader,
                        char filename[]);

#endif /* _chip8_image_bundle_h_ */

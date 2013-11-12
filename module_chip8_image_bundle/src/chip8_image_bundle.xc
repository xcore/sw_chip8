#include "chip8_image_bundle.h"
#include "syscall.h"

typedef struct chip8_image_bundle_header_t {
  uint32_t num_entries;
  uint32_t string_table_size;
  uint32_t data_table_size;
} chip8_image_bundle_header_t;

static int open_image_bundle(const char filename[], int &fd,
                             chip8_image_bundle_header_t &header)
{
  fd = _open(filename, O_RDONLY | O_BINARY, 0);
  if (fd < 0)
    return -1;
  int bytes_read = _read(fd, (char*)&header, sizeof(header));
  if (bytes_read < sizeof(header))
    return -1;
  return 0;
}

static int get_entries(int fd, const chip8_image_bundle_header_t &header,
                       chip8_image_bundle_entry_t entries[max_entries],
                       unsigned max_entries, char strings[string_table_size],
                       unsigned string_table_size)
{
  if (header.num_entries > max_entries ||
      header.string_table_size > string_table_size)
    return -1;
  if (_lseek(fd, sizeof(header), SEEK_SET) < 0)
    return -1;
  unsigned size = sizeof(entries[0]) * header.num_entries;
  int bytes_read = _read(fd, (char*)entries, size);
  if (bytes_read < size)
    return -1;
  bytes_read = _read(fd, strings, header.string_table_size);
  if (bytes_read < header.string_table_size)
    return -1;
  return header.num_entries;
}

static int get_image(int fd, const chip8_image_bundle_header_t &header,
                     char dst[], const chip8_image_bundle_entry_t &entry)
{
  unsigned pos = sizeof(chip8_image_bundle_header_t) +
                 header.num_entries * sizeof(chip8_image_bundle_entry_t) +
                 header.string_table_size;
  pos += entry.data_offset;
  if (_lseek(fd, pos, SEEK_SET) < 0)
    return -1;
  int bytes_read = _read(fd, dst, entry.data_size);
  if (bytes_read < entry.data_size)
    return -1;
  return entry.data_size;
}

[[distributable]]
void chip8_image_reader_file(server interface chip8_image_reader reader,
                             char filename[])
{
  int fd;
  chip8_image_bundle_header_t header;
  int error = open_image_bundle(filename, fd, header) < 0;
  while (1) {
    select {
    case reader.get_entries(chip8_image_bundle_entry_t *entries,
                            unsigned max_entries, char *strings,
                            unsigned string_table_size) -> int num_entries:
      if (error) {
        num_entries = -1;
      } else {
        num_entries = get_entries(fd, header, entries, max_entries, strings,
                                  string_table_size);
      }
      break;
    case reader.get_image(char *dst, const chip8_image_bundle_entry_t entry)
           -> int image_size:
      if (error) {
        image_size = -1;
      } else {
        image_size = get_image(fd, header, dst, entry);
      }
      break;
    case reader.close():
      _close(fd);
      return;
    }
  }
}

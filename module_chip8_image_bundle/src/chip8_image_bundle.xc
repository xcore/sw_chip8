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

typedef struct unpacked_ptr_t {
  char * unsafe ptr;
  char * unsafe base;
  unsigned size;
} unpacked_ptr_t;

unsafe static unpacked_ptr_t unpack_ptr(char * movable p) {
  return *(unpacked_ptr_t *)&p;
}

unsafe static char * movable pack_ptr(const unpacked_ptr_t &p) {
  return move(*(char * movable * unsafe)&p);
}

{char * movable, char * movable} static
split_ptr(char * movable p, unsigned offset)
{
  unsafe {
    unpacked_ptr_t low, high;
    low = unpack_ptr(move(p));
    high = low;
    high.ptr = high.base = low.ptr + offset;
    low.size = high.ptr - low.base;
    high.size -= low.size;
    return { pack_ptr(low), pack_ptr(high) };
  }
}

static char * movable join_ptr(char * movable l, char * movable h)
{
  unsafe {
    unpacked_ptr_t low, high;
    low = unpack_ptr(move(l));
    high = unpack_ptr(move(h));
    if (low.base + low.size != high.base)
      __builtin_trap();
    low.size += high.size;
    return pack_ptr(low);
  }
}

char * movable
chip8_image_reader_recycle_entry_list(chip8_image_bundle_entry_list_t &el) {
  return join_ptr((char * movable)move(el.entries), move(el.strings));
}

static int
get_entries(int fd, const chip8_image_bundle_header_t &header,
            chip8_image_bundle_entry_list_t &entry_list,
            char * movable buffer, unsigned buffer_size)
{
  unsigned entries_size = header.num_entries * sizeof(entry_list.entries[0]);
  unsigned size = entries_size + header.string_table_size;
  if (_lseek(fd, sizeof(header), SEEK_SET) < 0)
    return -1;
  int bytes_read = _read(fd, buffer, size);
  if (bytes_read < size)
    return -1;
  char * movable tmp;
  { tmp, entry_list.strings } = split_ptr(move(buffer), entries_size);
  entry_list.entries = (chip8_image_bundle_entry_t * movable)move(tmp);
  entry_list.num_entries = header.num_entries;
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
    case reader.get_entries(chip8_image_bundle_entry_list_t *entry_list,
                            char * movable buffer, unsigned buffer_size) -> int num_entries:
      if (error) {
        num_entries = -1;
      } else {
        num_entries = get_entries(fd, header, *entry_list, move(buffer),
                                  buffer_size);
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

#!/usr/bin/env python

import re
from os import listdir
from os.path import isfile, join
import io
import struct

image_path = "images"

def is_chip8_image(path, name):
  if not isfile(join(path, name)):
    return None
  m = re.search(r"^(.*)\.ch8$", name)
  if not m:
    return None
  return m.groups()[0]


def get_images(path):
  images = []
  for f in listdir(path):
    full_path = join(path, f)
    name = is_chip8_image(path, f)
    if not name is None:
      images.append((name, join(path, f)))
  return images


def write_image_bundle(images, filename):
  class Entry:
    def __init__(self):
      self.string = None
      self.data = None
      self.size = None

  f = io.open(filename, 'wb')
  header_size = 3 * 4
  entry_size = 3 * 4
  # Write header / entry placeholders
  for _ in range(header_size + len(images) * entry_size):
    f.write('\0')
  entries = []
  for _ in range(len(images)):
    entries.append(Entry())
  # Write string table
  string_start = f.tell()
  for elem in enumerate(images):
    name = elem[1][0]
    offset = f.tell() - string_start
    f.write(name)
    f.write('\0')
    entries[elem[0]].string = offset
  string_size = f.tell() - string_start
  # Write data table
  data_start = f.tell()
  for elem in enumerate(images):
    path = elem[1][1]
    image = io.open(path, 'rb')
    offset = f.tell() - data_start
    f.write(image.read())
    entries[elem[0]].data = offset
    entries[elem[0]].size = image.tell()
    image.close()
  data_size = f.tell() - data_start
  # Go back and fill in the header
  f.seek(0)
  f.write(struct.pack('<III',
                      len(entries),
                      string_size,
                      data_size))
  # Fill in entries
  for entry in entries:
    f.write(struct.pack('<III',
                        entry.string,
                        entry.data,
                        entry.size))
  f.close()


def main():
  images = get_images(image_path)
  write_image_bundle(images, 'images.bin')


main()

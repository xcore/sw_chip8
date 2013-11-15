#include "ps2.h"
#include <xs1.h>

static int parity(unsigned data)
{
  unsigned parity = data;
  crc32(parity, 0, 0x1);
  return parity;
}

[[combinable]]
void ps2_server(ps2_ports_t &ports, client interface ps2_callback callback)
{
  int clkVal;
  ports.clk :> clkVal;
  enum state {
    START_BIT,
    DATA_BIT,
    PARITY_BIT,
    STOP_BIT,
  } state = START_BIT;
  unsigned data;
  unsigned numBits;
  while (1) {
    select {
    case ports.clk when pinsneq(clkVal) :> clkVal:
      // Ignore falling edge, sample on rising.
      if (!clkVal)
        break;
      int bit;
      ports.data :> bit;
      switch (state) {
      case START_BIT:
        if (bit == 0) {
          state = DATA_BIT;
          data = 0;
          numBits = 0;
        }
        break;
      case DATA_BIT:
        data = (bit << 7) | (data >> 1);
        if (++numBits == 8)
          state = PARITY_BIT;
        break;
      case PARITY_BIT:
        if (parity(data) == bit) {
          state = STOP_BIT;
        } else {
          state = START_BIT;
        }
        break;
      case STOP_BIT:
        if (bit == 1) {
          callback.data(data);
        }
        state = START_BIT;
        break;
      }
      break;
    }
  }
}

#ifndef PS2_H_
#define PS2_H_

#include <stdint.h>

typedef struct ps2_ports_t {
  port clk;
  port data;
} ps2_ports_t;

interface ps2_callback {
  void data(uint8_t data);
};

[[combinable]]
void ps2_server(ps2_ports_t &ports, client interface ps2_callback callback);

#endif /* PS2_H_ */

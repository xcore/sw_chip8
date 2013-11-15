#include <platform.h>
#include <ps2.h>
#include <ps2_keyboard.h>

on tile[0] : struct ps2_ports_t ps2_ports = {
  XS1_PORT_1A, // Clock.
  XS1_PORT_1L, // Data.
};

[[distributable]]
static void print_events(server interface ps2_keyboard_callback keyboard)
{
  while (1) {
    select {
    case keyboard.event(enum ps2_keyboard_event type, uint8_t data):
      ps2_keyboard_print_event(type, data);
      break;
    }
  }
}

int main()
{
  interface ps2_callback ps2_callback;
  interface ps2_keyboard_callback ps2_keyboard_callback;
  par {
    on tile[0]: print_events(ps2_keyboard_callback);
    on tile[0]: ps2_keyboard(ps2_callback, ps2_keyboard_callback);
    on tile[0]: ps2_server(ps2_ports, ps2_callback);
  }
  return 0;
}

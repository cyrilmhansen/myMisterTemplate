#include "Vmycore.h"
#include "Vmycore___024root.h"
#include "verilated.h"

#include <cstdint>
#include <iostream>

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    Verilated::traceEverOn(false);

    Vmycore top;

    top.pal = 0;
    top.scandouble = 0;
    top.reset = 1;

    // Apply reset for a few cycles
    for (int i = 0; i < 8; ++i) {
        top.clk = 0;
        top.eval();
        top.clk = 1;
        top.eval();
    }

    top.reset = 0;

    // Run enough cycles for the FemtoRV32 program to execute several iterations.
    const int total_cycles = 2000;
    for (int cycle = 0; cycle < total_cycles; ++cycle) {
        top.clk = 0;
        top.eval();
        top.clk = 1;
        top.eval();
    }

    uint32_t led_value = top.rootp->mycore__DOT__cpu_led_reg;
    std::cout << "CPU LED register value: 0x" << std::hex << led_value << std::dec << std::endl;
    std::cout << "Lower byte decimal value: " << (led_value & 0xFFu) << std::endl;

    if ((led_value & 0xFFu) > 1) {
        std::cout << "FemtoRV32 loop executed successfully." << std::endl;
        return 0;
    }

    std::cerr << "Unexpected value observed. FemtoRV32 may not have executed as expected." << std::endl;
    return 1;
}

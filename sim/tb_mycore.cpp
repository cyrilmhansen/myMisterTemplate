#include <memory>

#include "Vmycore.h"
#include "Vmycore___024root.h"
#include "verilated.h"

int main(int argc, char **argv) {
    Verilated::commandArgs(argc, argv);
    auto contextp = std::make_unique<VerilatedContext>();
    contextp->commandArgs(argc, argv);
    auto top = std::make_unique<Vmycore>(contextp.get());

    top->clk = 0;
    top->reset = 1;
    top->pal = 0;
    top->scandouble = 0;

    for (int i = 0; i < 10; ++i) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();
    }

    top->reset = 0;

    uint8_t last = top->rootp->mycore__DOT__demo_cpu__DOT__led_reg;
    bool progressed = false;

    for (int cycle = 0; cycle < 2000 && !progressed; ++cycle) {
        top->clk = 0;
        top->eval();
        top->clk = 1;
        top->eval();

        uint8_t current = top->rootp->mycore__DOT__demo_cpu__DOT__led_reg;
        if (current != last) {
            progressed = true;
        }
        last = current;
    }

    if (!progressed) {
        VL_PRINTF("CPU did not update the LED register as expected.\n");
        return 1;
    }

    VL_PRINTF("CPU updated LED register to %u.\n", last);
    top->final();
    return 0;
}

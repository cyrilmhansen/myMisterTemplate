TOP        = mycore
RTL_DIR    = ../rtl
OBJ_DIR    = obj_dir

VERILATOR_FLAGS = --cc --sv --language 1800-2017 -DSIM_VERILATOR --exe --build -O3 -Wno-WIDTHTRUNC -Wno-WIDTHEXPAND -Wno-UNOPTFLAT \
-I$(RTL_DIR) \
$(RTL_DIR)/mycore.v \
$(RTL_DIR)/lfsr.v \
$(RTL_DIR)/cos.sv \
$(RTL_DIR)/femtorv32_gracilis.v \
sim_main.cpp

.PHONY: run clean

run: $(OBJ_DIR)/V$(TOP)
	./$(OBJ_DIR)/V$(TOP)

$(OBJ_DIR)/V$(TOP): sim_main.cpp
	verilator $(VERILATOR_FLAGS) --top-module $(TOP) --Mdir $(OBJ_DIR)

clean:
	rm -rf $(OBJ_DIR)

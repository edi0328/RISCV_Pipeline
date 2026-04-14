vlib work
vcom src/memory.vhd
vcom src/alu.vhd
vcom src/alu_ctrl.vhd
vcom src/registers.vhd
vcom src/hazard_unit.vhd
vcom src/pipeline.vhd
vcom sim/tb_pipeline.vhd

# Load the simulation
vsim work.tb_pipeline

mem load -fillbin -file sim/program.txt -format binary /tb_pipeline/dut/I_mem/ram_block

run 10000 ns

mem save -o memory.txt -f mti /tb_pipeline/dut/D_mem/ram_block
mem save -o register_file.txt -f mti /tb_pipeline/dut/rgs/regs

echo "Simulation complete. Output files generated."

# RISC-V pipeline

A five-stage RISC-V processor built in VHDL for McGill's ECSE 425 course.

The design separates instruction fetch, decode, execute, memory access, and writeback. A hazard unit stalls dependent instructions and inserts bubbles. Taken branches and jumps flush younger instructions.

## Implementation

- Arithmetic, logic, shifts, comparisons, and multiplication
- Word loads and stores
- Conditional branches, JAL, JALR, LUI, and AUIPC
- Separate instruction and data memory models

This is a course implementation of an instruction subset. It is not a complete RISC-V core.

## Simulation

Use Questa or ModelSim with `vcom` and `vsim` on your path. From the repository root:

```bash
vsim -c -do "do testbench.tcl"
```

The script compiles the design, loads `sim/program.txt` into instruction memory, and runs the simulation. It writes `memory.txt` and `register_file.txt` for inspection.

The clock period in the testbench is a simulation setting, not a measured hardware frequency.

## Files

- `src/pipeline.vhd`: datapath and control
- `src/hazard_unit.vhd`: stalls and flushes
- `src/alu.vhd` and `src/alu_ctrl.vhd`: execution logic
- `src/registers.vhd` and `src/memory.vhd`: storage
- `sim/` and `testbench.tcl`: simulation inputs and driver
- `riscv_assembler/riscv_assembler/`: bundled Python assembler

For Quartus, open `RISC_Pipeline.qpf`. The project targets a Cyclone V device. See the assembler's [notes](riscv_assembler/riscv_assembler/README.md) before using it to prepare new programs.

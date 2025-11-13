set_property LOC RAMB36_X0Y6 [get_cells top_inst/genblk1[0].Memory_Inst/*/*mem1*/*/*mem_reg]

startgroup
create_pblock pblock_u_picorv32
resize_pblock pblock_u_picorv32 -add {SLICE_X0Y2:SLICE_X15Y50 DSP48_X0Y2:DSP48_X0Y19 RAMB18_X0Y2:RAMB18_X0Y19 RAMB36_X0Y1:RAMB36_X0Y9}
add_cells_to_pblock pblock_u_picorv32 [get_cells [list top_inst/u_picorv32]]
endgroup
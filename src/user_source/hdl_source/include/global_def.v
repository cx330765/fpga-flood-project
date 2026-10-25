


`define   DATA_WIDTH                        32
`define   ADDR_WIDTH                        21
`define   DM_WIDTH                          4

`define   ROW_WIDTH                        11
`define   BA_WIDTH                        2

// Stage-2 timing repair: the frame-buffer SDRAM clock is 50 MHz. The refresh
// interval below is frequency-derived, so it must match sys_pll C1/C2.
`define	  SDR_CLK_PERIOD				1000000000/50000000
`define   SELF_REFRESH_INTERVAL			64000000/`SDR_CLK_PERIOD/2**(`ROW_WIDTH)


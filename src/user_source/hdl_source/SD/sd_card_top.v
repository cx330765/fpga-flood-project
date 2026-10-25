
module sd_card_top
#(
	parameter  SPI_LOW_SPEED_DIV = 248,         // SD card low speed mode frequency division parameter,spi clk speed = clk speed /((SPI_LOW_SPEED_DIV + 2) * 2 )
	parameter  SPI_HIGH_SPEED_DIV = 0,          // SD card high speed mode frequency division parameter
	parameter integer CLK_FREQ_HZ = 50_000_000,
	parameter integer PROBE_INTERVAL_CYCLES = CLK_FREQ_HZ / 4,
	parameter integer IO_TIMEOUT_CYCLES = CLK_FREQ_HZ / 5,
	parameter integer INIT_TIMEOUT_CYCLES = CLK_FREQ_HZ * 2,
	parameter integer RECOVERY_CYCLES = CLK_FREQ_HZ / 20
)
(
	input            clk,
	input            rst,
	output           SD_nCS,                    //SD card chip select (SPI mode)
	output           SD_DCLK,                   //SD card clock
	output           SD_MOSI,                   //SD card controller data output
	input            SD_MISO,                   //SD card controller data input
	output           sd_init_done,              //SD card initialization is complete
	input            sd_sec_read,               //SD card sector read
	input[31:0]      sd_sec_read_addr,          //SD card sector read address
	output[7:0]      sd_sec_read_data,          //SD card sector read data
	output           sd_sec_read_data_valid,    //SD card sector read data valid
	output           sd_sec_read_end,           //SD card sector read end
	input            sd_sec_write,              //SD card sector write
	input[31:0]      sd_sec_write_addr,         //SD card sector write address
	input[7:0]       sd_sec_write_data,         //SD card sector write data
	output           sd_sec_write_data_req,     //SD card sector write data next clock is valid
	output           sd_sec_write_end           //SD card sector write end
);
wire[15:0]           spi_clk_div;               //SPI module clock division parameter
wire                 cmd_req;                   //SD card command request
wire                 cmd_req_ack;               //SD card command request response
wire                 cmd_req_error;             //SD card command request error
wire[47:0]           cmd;                       //SD card command
wire[7:0]            cmd_r1;                    //SD card expect response
wire[15:0]           cmd_data_len;              //SD card command read data length
wire                 block_read_req;            //SD card sector data read request
wire                 block_read_valid;          //SD card sector data read data valid
wire[7:0]            block_read_data;           //SD card sector data read data
wire                 block_read_req_ack;        //SD card sector data read response
wire                 block_write_req;           //SD card sector data write request
wire[7:0]            block_write_data;          //SD card sector data write data next clock is valid
wire                 block_write_data_rd;       //SD card sector data write data
wire                 block_write_req_ack;       //SD card sector data write response

wire                 nCS_ctrl;                  //SPI module chip select control
wire                 spi_wr_req;                //SPI module data sending request
wire                 spi_wr_ack;                //SPI module data request response
wire[7:0]            spi_data_in;               //SPI module send data
wire[7:0]            spi_data_out;              //SPI module data returned
wire[15:0]           clk_div;

// Recover only the SPI/SD controller. HDMI and SDRAM are never reset here.
// A sector is allowed to take longer while valid bytes keep arriving.
function integer counter_bits;
    input integer maximum;
    integer value;
    begin
        counter_bits = 1;
        value = maximum;
        while (value > 1) begin
            counter_bits = counter_bits + 1;
            value = value >> 1;
        end
    end
endfunction
localparam integer ACTIVE_MAX = (INIT_TIMEOUT_CYCLES > IO_TIMEOUT_CYCLES) ?
                                INIT_TIMEOUT_CYCLES : IO_TIMEOUT_CYCLES;
localparam integer TIMER_MAX = (ACTIVE_MAX > RECOVERY_CYCLES) ?
                               ACTIVE_MAX : RECOVERY_CYCLES;
localparam integer TIMER_BITS = counter_bits(TIMER_MAX);
localparam integer SPI_DIV_MAX = (SPI_LOW_SPEED_DIV > SPI_HIGH_SPEED_DIV) ?
                                 SPI_LOW_SPEED_DIV : SPI_HIGH_SPEED_DIV;
localparam integer SPI_COUNT_BITS = counter_bits(SPI_DIV_MAX + 1);
// Active-transfer timing and reset holdoff are mutually exclusive. Reuse
// one exactly-sized timer, preserving all original cycle thresholds.
reg [TIMER_BITS-1:0] watchdog_count;
reg recovery_active;
wire controller_rst = rst || recovery_active;
wire io_active = cmd_req || block_read_req || block_write_req;
wire io_progress = block_read_valid || block_write_data_rd;
wire ready_command_failed = sd_init_done && cmd_req_ack && cmd_req_error;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        watchdog_count <= 0;
        recovery_active <= 0;
    end else if (recovery_active) begin
        if (RECOVERY_CYCLES <= 1 || watchdog_count == RECOVERY_CYCLES - 1) begin
            watchdog_count <= 0;
            recovery_active <= 0;
        end else watchdog_count <= watchdog_count + 1'b1;
    end else if (ready_command_failed ||
                 (!sd_init_done && watchdog_count >= INIT_TIMEOUT_CYCLES - 1) ||
                 (sd_init_done && io_active && !io_progress &&
                  watchdog_count >= IO_TIMEOUT_CYCLES - 1)) begin
        watchdog_count <= 0;
        recovery_active <= 1;
    end else if (!sd_init_done || (io_active && !io_progress)) begin
        watchdog_count <= watchdog_count + 1'b1;
    end else begin
        watchdog_count <= 0;
    end
end
sd_card_sec_read_write
#(
	.SPI_LOW_SPEED_DIV(SPI_LOW_SPEED_DIV),
	.SPI_HIGH_SPEED_DIV(SPI_HIGH_SPEED_DIV),
	.PROBE_INTERVAL_CYCLES(PROBE_INTERVAL_CYCLES)
)
sd_card_sec_read_write_m0(
	.clk                            (clk                    ),
	.rst                            (controller_rst         ),
	.sd_init_done                   (sd_init_done           ),
	.sd_sec_read                    (sd_sec_read            ),
	.sd_sec_read_addr               (sd_sec_read_addr       ),
	.sd_sec_read_data               (sd_sec_read_data       ),
	.sd_sec_read_data_valid         (sd_sec_read_data_valid ),
	.sd_sec_read_end                (sd_sec_read_end        ),
	.sd_sec_write                   (sd_sec_write           ),
	.sd_sec_write_addr              (sd_sec_write_addr      ),
	.sd_sec_write_data              (sd_sec_write_data      ),
	.sd_sec_write_data_req          (sd_sec_write_data_req  ),
	.sd_sec_write_end               (sd_sec_write_end       ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
	.block_read_req                 (block_read_req         ),
	.block_read_valid               (block_read_valid       ),
	.block_read_data                (block_read_data        ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    )
);

// This controller only requests 0/1/4 response bytes. Its largest transfer
// counter value is 513 (512 payload bytes + two CRC bytes), so ten bits suffice.
sd_card_cmd #(.BYTE_COUNT_BITS(10)) sd_card_cmd_m0(
	.sys_clk                        (clk                    ),
	.rst                            (controller_rst         ),
	.spi_clk_div                    (spi_clk_div            ),
	.cmd_req                        (cmd_req                ),
	.cmd_req_ack                    (cmd_req_ack            ),
	.cmd_req_error                  (cmd_req_error          ),
	.cmd                            (cmd                    ),
	.cmd_r1                         (cmd_r1                 ),
	.cmd_data_len                   (cmd_data_len           ),
	.block_read_req                 (block_read_req         ),
	.block_read_req_ack             (block_read_req_ack     ),
	.block_read_data                (block_read_data        ),
	.block_read_valid               (block_read_valid       ),
	.block_write_req                (block_write_req        ),
	.block_write_data               (block_write_data       ),
	.block_write_data_rd            (block_write_data_rd    ),
	.block_write_req_ack            (block_write_req_ack    ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.clk_div                        (clk_div                ),
	.spi_wr_req                     (spi_wr_req             ),
	.spi_wr_ack                     (spi_wr_ack             ),
	.spi_data_in                    (spi_data_in            ),
	.spi_data_out                   (spi_data_out           )

);

spi_master #(.CLK_COUNT_BITS(SPI_COUNT_BITS)) spi_master_m0(
	.sys_clk                        (clk                    ),
	.rst                            (controller_rst         ),
	.nCS                            (SD_nCS                 ),
	.DCLK                           (SD_DCLK                ),
	.MOSI                           (SD_MOSI                ),
	.MISO                           (SD_MISO                ),
	.clk_div                        (clk_div                ),
	.CPOL                           (1'b1                   ),
	.CPHA                           (1'b1                   ),
	.nCS_ctrl                       (nCS_ctrl               ),
	.wr_req                         (spi_wr_req             ),
	.wr_ack                         (spi_wr_ack             ),
	.data_in                        (spi_data_in            ),
	.data_out                       (spi_data_out           )
);
endmodule

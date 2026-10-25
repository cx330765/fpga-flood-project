// ---------------- Simulation-only dependency stubs ----------------
module bmp_read #(parameter integer FAST_FIRST_IMAGE_ENABLE=0)(
    input clk, input rst, output reg ready,
    input scan_start, input scan_resume, input [31:0] scan_start_sector,
    input [31:0] scan_max_sector, input [2:0] scan_target_count,
    output reg scan_done, output reg scan_paused, output reg scan_found_valid,
    output reg [31:0] scan_found_sector, output reg [2:0] scan_found_total,
    input load_start, input [31:0] load_sector,
    input sd_init_done, output reg [3:0] state_code,
    input [15:0] bmp_width, input [15:0] bmp_height,
    output reg write_req, input write_req_ack,
    output reg sd_sec_read, output reg [31:0] sd_sec_read_addr,
    input [7:0] sd_sec_read_data, input sd_sec_read_data_valid,
    input sd_sec_read_end, output reg bmp_data_wr_en,
    output reg [23:0] bmp_data,
    output [15:0] source_width, output [15:0] source_height,
    output reg scale_start
);
reg [2:0] scan_count;
reg [7:0] load_count;
// Use a non-native size here so this control regression continues to exercise
// the scaler-completion handshake. Native 640x480 bypass has its own test.
assign source_width = 16'd320;
assign source_height = 16'd240;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        ready <= 1'b1; scan_done <= 1'b0; scan_paused<=0; scan_found_valid <= 1'b0;
        scan_found_sector <= 0; scan_found_total <= 0; scan_count <= 0;
        load_count <= 0; state_code <= 0; write_req <= 0;
        sd_sec_read <= 0; sd_sec_read_addr <= 0;
        bmp_data_wr_en <= 0; bmp_data <= 0; scale_start <= 0;
    end else begin
        scan_found_valid <= 1'b0;
        scale_start <= 1'b0;
        write_req <= 1'b0;
        if (scan_start) begin
            ready <= 1'b0; scan_done <= 1'b0; scan_count <= 0;
            scan_paused<=0;
            scan_found_total <= 0;
        end else if (FAST_FIRST_IMAGE_ENABLE && scan_resume && scan_paused) begin
            scan_paused<=0;ready<=0;
        end else if (!scan_done && !scan_paused && !ready && load_count==0) begin
            scan_found_valid <= 1'b1;
            scan_found_sector <= 32'd100 + scan_count;
            scan_found_total <= scan_count + 1'b1;
            if (scan_count == 3) begin
                scan_done <= 1'b1; ready <= 1'b1;
            end else begin
                scan_count <= scan_count + 1'b1;
                if(FAST_FIRST_IMAGE_ENABLE && scan_count==0)begin scan_paused<=1;ready<=1;end
            end
        end

        if (load_start) begin
            ready <= 1'b0; load_count <= 4'd1; scale_start <= 1'b1;
            write_req <= 1'b1;
        end else if (load_count != 0) begin
            // Keep the source busy long enough for the test to observe that
            // emergency status changes only after buffer commit.
            if (load_count == 100) begin
                load_count <= 0; ready <= 1'b1;
            end else begin
                load_count <= load_count + 1'b1;
            end
        end
    end
end
endmodule

module bilinear_scaler_stream #(
    parameter integer OUT_WIDTH=640, OUT_HEIGHT=480, MAX_INPUT_WIDTH=1280
)(
    input clk, input rst, input frame_start,
    input [15:0] source_width, input [15:0] source_height,
    input in_valid, input [23:0] in_pixel,
    output reg out_valid, output reg [23:0] out_pixel,
    output reg frame_done, output reg busy, output reg overrun_error
);
reg [3:0] cnt;
always @(posedge clk or posedge rst) begin
    if (rst) begin
        cnt<=0; out_valid<=0; out_pixel<=0; frame_done<=0; busy<=0; overrun_error<=0;
    end else begin
        frame_done <= 0; out_valid <= 0;
        if (frame_start) begin cnt<=1; busy<=1; end
        else if (cnt != 0) begin
            if (cnt == 6) begin cnt<=0; busy<=0; frame_done<=1; end
            else cnt<=cnt+1'b1;
        end
    end
end
endmodule

module sd_card_top #(parameter integer CLK_FREQ_HZ=50_000_000)(
    input clk, input rst, output SD_nCS, output SD_DCLK, output SD_MOSI,
    input SD_MISO, output sd_init_done,
    input sd_sec_read, input [31:0] sd_sec_read_addr,
    output [7:0] sd_sec_read_data, output sd_sec_read_data_valid,
    output sd_sec_read_end, input sd_sec_write,
    input [31:0] sd_sec_write_addr, input [7:0] sd_sec_write_data,
    output sd_sec_write_data_req, output sd_sec_write_end
);
assign SD_nCS=1'b1; assign SD_DCLK=1'b0; assign SD_MOSI=1'b0;
assign sd_init_done=~rst; assign sd_sec_read_data=8'd0;
assign sd_sec_read_data_valid=1'b0; assign sd_sec_read_end=1'b0;
assign sd_sec_write_data_req=1'b0; assign sd_sec_write_end=1'b0;
endmodule

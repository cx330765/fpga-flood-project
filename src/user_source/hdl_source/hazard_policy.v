// Demo inputs, not a certified evacuation controller. Logical 1 = hazard.
module hazard_policy #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter [3:0] SWITCH_ACTIVE_LOW = 4'b0000
)(
    input wire clk, reset,
    input wire [3:0] switches,
    output reg [3:0] hazards,
    output wire active, evacuation, all_exits_blocked,
    output wire route_b, route_locked,
    output wire [2:0] reason
);
    localparam integer RAW_CYCLES = (CLK_FREQ_HZ / 1000) * DEBOUNCE_MS;
    localparam integer CYCLES = RAW_CYCLES < 1 ? 1 : RAW_CYCLES;
    reg [3:0] sync0, sync1, candidate;
    reg [31:0] stable_count;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            sync0<=0; sync1<=0; candidate<=0; hazards<=0; stable_count<=0;
        end else begin
            sync0 <= switches ^ SWITCH_ACTIVE_LOW;
            sync1 <= sync0;
            // Qualify the complete vector: do not publish partial combinations.
            if (sync1 != candidate) begin candidate<=sync1; stable_count<=0; end
            else if (hazards != candidate) begin
                if (stable_count >= CYCLES-1) begin hazards<=candidate; stable_count<=0; end
                else stable_count<=stable_count+1'b1;
            end else stable_count<=0;
        end
    end
    assign active = |hazards;
    assign evacuation = hazards[3] | hazards[1] | hazards[0];
    assign all_exits_blocked = hazards[1] & hazards[0];
    assign route_b = hazards[0] & ~hazards[1];
    assign route_locked = hazards[0] | hazards[1];
    // 0 normal, 1 medical, 2 A blocked, 3 B blocked, 4 both, 5 secondary.
    // Availability always vetoes an unsafe route, including secondary danger.
    assign reason = hazards[3] ? 3'd5 : all_exits_blocked ? 3'd4 :
                    hazards[0] ? 3'd2 : hazards[1] ? 3'd3 :
                    hazards[2] ? 3'd1 : 3'd0;
endmodule

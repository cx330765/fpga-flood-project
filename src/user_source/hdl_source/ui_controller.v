// Stage 1: the only owner of physical KEY2/KEY3/KEY4.
// Runtime values are applied immediately; reset restores defaults.
module ui_controller #(
    parameter integer CLK_FREQ_HZ = 50_000_000,
    parameter integer DEBOUNCE_MS = 20,
    parameter integer LONG_PRESS_MS = 1500,
    parameter integer MENU_TIMEOUT_SECONDS = 10,
    parameter integer HAZARD_POLICY_ENABLE = 0,
    parameter integer GROUPED_MENU_ENABLE = 0,
    parameter [4:0] DEFAULT_HOUR = 5'd12,
    parameter [5:0] DEFAULT_MINUTE = 6'd0,
    parameter [5:0] DEFAULT_SECOND = 6'd0
)(
    input wire clk, reset,
    input wire key2_n, key3_n, key4_n,
    input wire emergency_mode, player_ready,
    input wire hazard_active,
    output wire next_image_pulse,
    output wire emergency_toggle_pulse,
    output wire auto_or_route_pulse,
    output wire playback_pause,
    output reg menu_active,
    output reg [3:0] menu_item,
    output reg [9:0] menu_value,
    output wire [3:0] brightness_level,
    output reg [3:0] contrast_level, saturation_level,
    output reg auto_brightness,
    output wire adjust_mode, saturation_mode, time_set_mode,
    output reg [4:0] clock_hour,
    output reg [5:0] clock_minute, clock_second,
    output wire [1:0] status_edit_mode,
    output reg [3:0] people_hundreds, people_tens, people_ones,
    output reg [1:0] material_state, medical_state,
    output reg [1:0] volume_level, subtitle_speed,
    output reg [2:0] playback_order,
    output wire [1:0] menu_group
);
    localparam [3:0] BRIGHT=0, CONTRAST=1, SATURATION=2, AUTO_BRIGHT=3,
                      HOUR=4, MINUTE=5, PEOPLE=6, MATERIAL=7, MEDICAL=8,
                      VOLUME=9, SPEED=10, ORDER=11;
    assign menu_group = menu_item<=3 ? 2'd0 : menu_item<=5 ? 2'd1 : menu_item<=8 ? 2'd2 : 2'd3;
    wire group_change = (GROUPED_MENU_ENABLE != 0) && menu_active && k4_menu_owner &&
                        k4_long && !k2_short && !k2_long && !k3_long;
    wire [3:0] group_first = menu_group==0 ? BRIGHT : menu_group==1 ? HOUR : menu_group==2 ? PEOPLE : VOLUME;
    wire [3:0] group_last = menu_group==0 ? AUTO_BRIGHT : menu_group==1 ? MINUTE : menu_group==2 ? MEDICAL : ORDER;
    localparam integer SECOND_CYCLES = (CLK_FREQ_HZ < 1) ? 1 : CLK_FREQ_HZ;
    localparam integer TIMEOUT_CYCLES = SECOND_CYCLES * MENU_TIMEOUT_SECONDS;
    wire k2_press, k3_press, k4_press, k2_short, k3_short, k4_short;
    wire k2_long, k3_long, k4_long, k2_held, k3_held, k4_held;
    reg k2_menu_owner, k4_menu_owner, k4_emergency_owner;
    reg k2_policy_owner, k4_policy_owner;
    reg [31:0] idle_count, second_count;
    reg [3:0] manual_brightness;
    wire clock_edit = menu_active && (menu_item == HOUR || menu_item == MINUTE);
    wire inc = menu_active && k3_short && !k2_short && !k2_long && !k3_long && !group_change;
    wire dec = menu_active && k4_short && k4_menu_owner && !k2_short &&
               !k3_short && !k2_long && !k3_long && !group_change;
    wire daytime = clock_hour >= 6 && clock_hour < 18;
    wire policy_lock = (HAZARD_POLICY_ENABLE != 0) && hazard_active;

    ui_key_events #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS),
        .LONG_PRESS_MS(LONG_PRESS_MS)) key2_events (
        .clk(clk), .reset(reset), .button_n(key2_n), .press_pulse(k2_press),
        .short_pulse(k2_short), .long_pulse(k2_long), .held(k2_held));
    ui_key_events #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS),
        .LONG_PRESS_MS(LONG_PRESS_MS)) key3_events (
        .clk(clk), .reset(reset), .button_n(key3_n), .press_pulse(k3_press),
        .short_pulse(k3_short), .long_pulse(k3_long), .held(k3_held));
    ui_key_events #(.CLK_FREQ_HZ(CLK_FREQ_HZ), .DEBOUNCE_MS(DEBOUNCE_MS),
        .LONG_PRESS_MS(LONG_PRESS_MS)) key4_events (
        .clk(clk), .reset(reset), .button_n(key4_n), .press_pulse(k4_press),
        .short_pulse(k4_short), .long_pulse(k4_long), .held(k4_held));

    // Remember the context at press-down. A release after a mode change
    // must not toggle autoplay or accidentally select a route.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            k2_menu_owner <= 0; k4_menu_owner <= 0; k4_emergency_owner <= 0;
            k2_policy_owner <= 0; k4_policy_owner <= 0;
        end else begin
            if (k2_press) begin
                k2_menu_owner <= menu_active;
                k2_policy_owner <= policy_lock;
            end
            if (k4_press) begin
                k4_menu_owner <= menu_active;
                k4_emergency_owner <= emergency_mode;
                k4_policy_owner <= policy_lock;
            end
        end
    end
    assign emergency_toggle_pulse = k2_long && player_ready && !policy_lock && !k2_policy_owner;
    assign next_image_pulse = k2_short && !k2_menu_owner && !menu_active &&
                              !emergency_mode && !k3_long && !k3_held && !policy_lock && !k2_policy_owner;
    assign auto_or_route_pulse = k4_short && !k4_menu_owner && !menu_active &&
        (k4_emergency_owner == emergency_mode) && (k4_policy_owner == policy_lock) &&
        !k2_short && !k2_long && !k3_long && !k3_held;
    // Pause automatic advances from KEY3 press-down to menu close; this also
    // prevents autoplay racing the exact menu-entry clock edge.
    assign playback_pause = menu_active || (!emergency_mode && k3_held) ||
                            k3_long || k2_long;
    assign brightness_level = auto_brightness ? (daytime ? 4'd12 : 4'd8) : manual_brightness;
    assign adjust_mode = menu_active && (menu_item == CONTRAST || menu_item == MINUTE);
    assign saturation_mode = menu_active && menu_item == SATURATION;
    assign time_set_mode = clock_edit;
    assign status_edit_mode = !menu_active ? 2'd0 :
        menu_item == PEOPLE ? 2'd1 : menu_item == MATERIAL ? 2'd2 :
        menu_item == MEDICAL ? 2'd3 : 2'd0;

    always @(*) begin
        case (menu_item)
            BRIGHT: menu_value = {6'd0, brightness_level};
            CONTRAST: menu_value = {6'd0, contrast_level};
            SATURATION: menu_value = {6'd0, saturation_level};
            AUTO_BRIGHT: menu_value = {9'd0, auto_brightness};
            HOUR: menu_value = {5'd0, clock_hour};
            MINUTE: menu_value = {4'd0, clock_minute};
            PEOPLE: menu_value = people_hundreds * 10'd100 + people_tens * 10'd10 + people_ones;
            MATERIAL: menu_value = {8'd0, material_state};
            MEDICAL: menu_value = {8'd0, medical_state};
            VOLUME: menu_value = volume_level==0 ? 10'd25 : volume_level==1 ? 10'd50 : volume_level==2 ? 10'd75 : 10'd100;
            SPEED: menu_value = {8'd0,subtitle_speed} + 10'd1;
            ORDER: case(playback_order)
                0:menu_value=123;1:menu_value=132;2:menu_value=213;
                3:menu_value=231;4:menu_value=312;default:menu_value=321;
            endcase
            default: menu_value = 0;
        endcase
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin menu_active <= 0; menu_item <= BRIGHT; idle_count <= 0; end
        else if (emergency_mode || k2_long || policy_lock) begin
            menu_active <= 0; idle_count <= 0;
        end else if (k3_long) begin
            if (menu_active) menu_active <= 0;
            else if (player_ready) begin menu_active <= 1; menu_item <= BRIGHT; end
            idle_count <= 0;
        end else if (menu_active) begin
            if (group_change) begin
                case(menu_group)
                    0:menu_item<=HOUR;1:menu_item<=PEOPLE;2:menu_item<=VOLUME;default:menu_item<=BRIGHT;
                endcase
            end else if (k2_short && k2_menu_owner) begin
                if (GROUPED_MENU_ENABLE != 0)
                    menu_item <= (menu_item==group_last) ? group_first : menu_item+1'b1;
                else menu_item <= (menu_item == MEDICAL) ? BRIGHT : menu_item + 1'b1;
            end
            if (k2_held || k3_held || k4_held || k2_short || k3_short || k4_short)
                idle_count <= 0;
            else if (idle_count >= TIMEOUT_CYCLES - 1) begin menu_active <= 0; idle_count <= 0; end
            else idle_count <= idle_count + 1'b1;
        end else idle_count <= 0;
    end

    // Keep the original visible presets: 4, 8, 12, 15. Both directions wrap.
    function [3:0] next_picture_level;
        input [3:0] level;
        begin
            case (level)
                4'd4: next_picture_level = 4'd8;
                4'd8: next_picture_level = 4'd12;
                4'd12: next_picture_level = 4'd15;
                default: next_picture_level = 4'd4;
            endcase
        end
    endfunction
    function [3:0] previous_picture_level;
        input [3:0] level;
        begin
            case (level)
                4'd15: previous_picture_level = 4'd12;
                4'd12: previous_picture_level = 4'd8;
                4'd8: previous_picture_level = 4'd4;
                default: previous_picture_level = 4'd15;
            endcase
        end
    endfunction

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            manual_brightness <= 8; contrast_level <= 8; saturation_level <= 8;
            auto_brightness <= 0;
            people_hundreds <= 1; people_tens <= 2; people_ones <= 0;
            material_state <= 0; medical_state <= 0;
            volume_level <= 3; subtitle_speed <= 1; playback_order <= 0;
        end else if (menu_active && !emergency_mode && !k2_long && !k3_long && !policy_lock) begin
            case (menu_item)
                BRIGHT: if (inc || dec) begin
                    auto_brightness <= 0;
                    if (inc) manual_brightness <= next_picture_level(brightness_level);
                    else manual_brightness <= previous_picture_level(brightness_level);
                end
                CONTRAST: if (inc) contrast_level <= next_picture_level(contrast_level);
                          else if (dec) contrast_level <= previous_picture_level(contrast_level);
                SATURATION: if (inc) saturation_level <= next_picture_level(saturation_level);
                            else if (dec) saturation_level <= previous_picture_level(saturation_level);
                AUTO_BRIGHT: if (inc || dec) auto_brightness <= ~auto_brightness;
                PEOPLE: begin
                    if (inc && !(people_hundreds == 9 && people_tens == 9 && people_ones == 9)) begin
                        if (people_ones == 9) begin
                            people_ones <= 0;
                            if (people_tens == 9) begin people_tens <= 0; people_hundreds <= people_hundreds + 1'b1; end
                            else people_tens <= people_tens + 1'b1;
                        end else people_ones <= people_ones + 1'b1;
                    end else if (dec && !(people_hundreds == 0 && people_tens == 0 && people_ones == 0)) begin
                        if (people_ones == 0) begin
                            people_ones <= 9;
                            if (people_tens == 0) begin people_tens <= 9; people_hundreds <= people_hundreds - 1'b1; end
                            else people_tens <= people_tens - 1'b1;
                        end else people_ones <= people_ones - 1'b1;
                    end
                end
                MATERIAL: if (inc) material_state <= (material_state == 2) ? 0 : material_state + 1'b1;
                          else if (dec) material_state <= (material_state == 0) ? 2 : material_state - 1'b1;
                MEDICAL: if (inc) medical_state <= (medical_state == 2) ? 0 : medical_state + 1'b1;
                         else if (dec) medical_state <= (medical_state == 0) ? 2 : medical_state - 1'b1;
                VOLUME: if(inc) volume_level<=(volume_level==3)?0:volume_level+1'b1;
                        else if(dec) volume_level<=(volume_level==0)?3:volume_level-1'b1;
                SPEED: if(inc) subtitle_speed<=(subtitle_speed==2)?0:subtitle_speed+1'b1;
                       else if(dec) subtitle_speed<=(subtitle_speed==0)?2:subtitle_speed-1'b1;
                ORDER: if(inc) playback_order<=(playback_order==5)?0:playback_order+1'b1;
                       else if(dec) playback_order<=(playback_order==0)?5:playback_order-1'b1;
                default: begin end
            endcase
        end
    end

    // Only clock items stop the clock. Other menu items leave it running.
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            second_count <= 0; clock_hour <= DEFAULT_HOUR;
            clock_minute <= DEFAULT_MINUTE; clock_second <= DEFAULT_SECOND;
        end else if (clock_edit && !emergency_mode && !k2_long && !policy_lock) begin
            second_count <= 0; clock_second <= 0;
            if (menu_item == HOUR) begin
                if (inc) clock_hour <= (clock_hour == 23) ? 0 : clock_hour + 1'b1;
                else if (dec) clock_hour <= (clock_hour == 0) ? 23 : clock_hour - 1'b1;
            end else begin
                if (inc) clock_minute <= (clock_minute == 59) ? 0 : clock_minute + 1'b1;
                else if (dec) clock_minute <= (clock_minute == 0) ? 59 : clock_minute - 1'b1;
            end
        end else if (second_count >= SECOND_CYCLES - 1) begin
            second_count <= 0;
            if (clock_second == 59) begin
                clock_second <= 0;
                if (clock_minute == 59) begin
                    clock_minute <= 0; clock_hour <= (clock_hour == 23) ? 0 : clock_hour + 1'b1;
                end else clock_minute <= clock_minute + 1'b1;
            end else clock_second <= clock_second + 1'b1;
        end else second_count <= second_count + 1'b1;
    end
endmodule

// Active-low keys: short on debounced release, long once at threshold.
// Contact bounce never generates both short and long for the same hold.
module ui_key_events #(
    parameter integer CLK_FREQ_HZ=50_000_000,
    parameter integer DEBOUNCE_MS=20,
    parameter integer LONG_PRESS_MS=1500
)(
    input wire clk, reset, button_n,
    output reg press_pulse, short_pulse, long_pulse,
    output wire held
);
    localparam integer DB_RAW=(CLK_FREQ_HZ/1000)*DEBOUNCE_MS;
    localparam integer LP_RAW=(CLK_FREQ_HZ/1000)*LONG_PRESS_MS;
    localparam integer DB=(DB_RAW < 1) ? 1 : DB_RAW;
    localparam integer LP=(LP_RAW < 1) ? 1 : LP_RAW;
    reg meta, synced, stable, long_seen;
    reg [31:0] db_count, hold_count;
    assign held = !stable;
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            meta <= 1; synced <= 1; stable <= 1; long_seen <= 0;
            db_count <= 0; hold_count <= 0;
            press_pulse <= 0; short_pulse <= 0; long_pulse <= 0;
        end else begin
            meta <= button_n; synced <= meta;
            press_pulse <= 0; short_pulse <= 0; long_pulse <= 0;
            if (synced != stable) begin
                if (db_count >= DB-1) begin
                    stable <= synced; db_count <= 0;
                    if (!synced) begin
                        press_pulse <= 1; hold_count <= 0; long_seen <= 0;
                    end else begin
                        if (!long_seen) short_pulse <= 1;
                        hold_count <= 0;
                    end
                end else db_count <= db_count + 1'b1;
            end else begin
                db_count <= 0;
                if (!stable && !long_seen) begin
                    if (hold_count >= LP-1) begin long_pulse <= 1; long_seen <= 1; end
                    else hold_count <= hold_count + 1'b1;
                end
            end
        end
    end
endmodule

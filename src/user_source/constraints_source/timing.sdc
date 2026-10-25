
# ============================================================
# merged_top_tf_hdmi_audio.sdc
# 用于：TF 图片轮播 + HDMI(视频+音频) 整合工程
#
# 合并原则：
# 1) 保留 top.sdc 里的系统主时钟与 derive_clocks
# 2) 把 timing(2).sdc 里的 pixel/serial 时钟改成整合工程实际名字
# 3) 增加 hdmi_5x_clk / audio_mclk 的命名
# 4) 不再对内部 net 直接 create_clock，避免和 derive_clocks 重复
# ============================================================

# ------------------------------------------------------------
# 1. 板级输入主时钟
#    你的原 top.sdc 里 clk=50MHz，所以这里仍然用 20ns
# ------------------------------------------------------------
create_clock -name clk -period 20 -waveform {0 10} [get_ports {clk}]

# ------------------------------------------------------------
# 2. 自动推导 PLL 输出时钟
# ------------------------------------------------------------
derive_clocks

# ------------------------------------------------------------
# 3. 给关键 PLL 输出命名
#    下面这些路径是按你当前工程实例名写的：
#      sys_pll      -> sys_pll_m0
#      video_pll    -> video_pll_m0
#      音频 PLL     -> u_audio_pll
#
#    如果综合后实例路径略有不同，就按 Timing Analyzer 里的实际 pin 路径改。
# ------------------------------------------------------------
# SD/BMP/scaler logic now uses the 50-MHz board input clock directly.  It is
# already constrained by the create_clock command above, so no PLL clock rename
# is needed for that domain.
rename_clock -name {ext_mem_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {sys_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {video_clk}   -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[0]}]
rename_clock -name {hdmi_5x_clk} -source [get_ports {clk}] -master_clock {clk} [get_pins {video_pll_m0/pll_inst.clkc[1]}]
rename_clock -name {audio_mclk}  -source [get_ports {clk}] -master_clock {clk} [get_pins {u_audio_pll/pll_inst.clkc[2]}]

# ------------------------------------------------------------
# 4. video_clk and hdmi_5x_clk are related outputs of the same PLL and are both
#    active in the HDMI transmitter. Do not mark them exclusive; derive_clocks
#    keeps their real 1:5 relationship available to timing analysis.

# ------------------------------------------------------------
# 5. 异步时钟分组（2026/10/12 修订，修复 hold 误报）
#
#    分组原则：
#    1) clk(50M) 与 ext_mem_clk(50M) 同源同频，保持同组做同步检查；
#    2) video_clk 与 hdmi_5x_clk 保持同组（TMDS 串行化 1:5 同步关系）；
#    3) 两组之间全部为异步跨域，且实际跨域处均有同步器/异步FIFO
#       （fade_black_sync 两级同步、read_req_d0 同步、afifo 异步FIFO），
#       切断组间 setup/hold 检查，消除同步器第一级 hold 误报
#       （此前报告：video->clk 2个、video->ext_mem 1个 endpoint）；
#    4) audio_mclk 单独一组（I2S 跨域均为三拍同步）。
# ------------------------------------------------------------
set_clock_groups -asynchronous \
    -group [get_clocks {clk ext_mem_clk}] \
    -group [get_clocks {video_clk hdmi_5x_clk}] \
    -group [get_clocks {audio_mclk}]


# ------------------------------------------------------------
# 7. 其余 Input/Output delay 先保持空白
#    你当前两个原始 sdc 也都没有写这部分。
# ------------------------------------------------------------

# 洪涝安置点多险情联动视听引导终端

基于安路 HX4S20C（EG4S20BG256）开发板的纯 RTL 离线视听引导终端。TF 卡读取中文 BMP，经 SDRAM 双缓冲、显示效果与 OSD 叠加后由 HDMI 输出，同时播放页面语音、告警音和撤离倒计时提示。

## 目标平台

- FPGA：EG4S20BG256
- 开发板：HX4S20C
- 工具：Tang Dynasty 6.2.168116
- 显示：HDMI B 口，640×480
- 存储：板载 TF 卡槽，FAT32
- 输入：KEY1～KEY4、SW1～SW4
- 输出：HDMI 画面与音频、6 位数码管调试显示

## 目录结构

```
src/
├─ td_project/                  TD 工程与已编译产物
│  ├─ HDMI1.4b_Transmitter_v1.0.al
│  ├─ HDMI1.4b_Transmitter_v1.0_final.bit
│  ├─ final_hold_check.tcl
│  ├─ rebuild_verified.tcl
│  ├─ open_packaged_project.tcl
│  └─ al_ip/
├─ user_source/
│  ├─ constraints_source/       pin.adc、timing.sdc
│  └─ hdl_source/               RTL、IP、语音 MIF 与生成脚本
├─ sim_first_image/             首图优先仿真
├─ sim_img4_alarm/              撤离页长警报仿真
├─ sim_ui/                      菜单、险情、OSD、轮播仿真
└─ 使用说明.txt
```

## 打开工程

直接打开：

```
src/td_project/HDMI1.4b_Transmitter_v1.0.al
```

如果 TD 没有自动加载源文件，在 Tcl Console 执行：

```tcl
source {<仓库路径>/src/td_project/open_packaged_project.tcl}
```

工程使用相对路径，不绑定本机目录。

## 完整重建

在 TD Tcl Console 执行：

```tcl
source {<仓库路径>/src/td_project/rebuild_verified.tcl}
```

脚本执行综合、`seed=2` 布局、布线、`fix_hold`，检查建立/保持时间后生成：

```
src/td_project/HDMI1.4b_Transmitter_v1.0_final.bit
```

## 时序证据

与仓库内 BIT `D4816582...` 对应的是下面两份构建汇总：

- `src/sim_first_image/工具验证结果.txt`（2026-10-18 18:08:44）
- `src/sim_first_image/验证记录.md`（2026-10-18 18:09:16）

两份文件都记录：

- Setup WNS：+0.174 ns
- Hold WNS：+0.023 ns
- Setup/Hold TNS：0
- STA 覆盖率：99.79%
- 物理资源：18259 LUT、7224 寄存器、4890/4889 MSlice/LSlice
- BIT：`D4816582BBB1253117E48B4493C2FA22E4248C3356FE45DCA462BC0E502A80D1`

仓库未附 `final_hold_checked.ts/timing`；以上两份构建汇总是可核对依据。

如果走 GUI 综合/布局/布线，布线完成后执行：

```tcl
source {<仓库路径>/src/td_project/final_hold_check.tcl}
```

检查生成的 `final_hold_checked.ts`，确认建立和保持均满足后，再执行：

```tcl
bitgen -bit HDMI1.4b_Transmitter_v1.0_final.bit
```

## 仓库内 BIT

```
src/td_project/HDMI1.4b_Transmitter_v1.0_final.bit
```

SHA256：

```
D4816582BBB1253117E48B4493C2FA22E4248C3356FE45DCA462BC0E502A80D1
```

烧录前请核对 BIT 的 SHA256 与上面一致。

## 仿真

ModelSim 脚本位于 `src/sim_*`。常用入口：

- `src/sim_ui/run_all.do`
- `src/sim_first_image/run_first_image.do`
- `src/sim_img4_alarm/run_img4_alarm.do`

仿真使用部分存储/ROM 模型，不能替代真实 TF 卡、SDRAM 与整机时序验证。

## 语音素材

`src/user_source/hdl_source/python/` 保存语音生成脚本、MIF 与试听 WAV。`voice_adpcm_rom.v`、`voice4_pcm_rom.v` 通过 `INIT_FILE` 引用 `python/voice_adpcm/` 下的 MIF，移动目录时需同步修改。

## 说明

- 本设计为纯 RTL，无 PC 端、云端程序和处理器软核。
- 机械结构直接采用开发板、现成保护板和显示器支架，无自研机械件。
- 电路直接使用 HX4S20C 板载接口，无自研 PCB。
- 详细操作与设计说明见 `src/使用说明.txt`。

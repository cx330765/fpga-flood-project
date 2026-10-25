# wav_to_voice_mif.py —— 把人声 WAV 转成 voice_rom 用的 8bit/8kHz .mif

import os
import sys
import wave
from math import gcd

import numpy as np

ROM_DEPTH = 32768      # voice_rom.v 的 DEPTH
TARGET_FS = 8000       # 8kHz，与模块的 VOICE_DIV=6 对应
SILENCE = 0x80         # 8bit 无符号的中点，即静音
PEAK_USE = 0.95        # 留 5% 余量，避免量化削顶
TARGET_RMS = 0.18      # 压缩后目标平均电平，相对峰值
GAIN_MAX = 10.0        # 增益上限，防止把底噪抬起来
GAIN_SMOOTH = 0.02     # 增益平滑系数，抗抽吸

# 用于先跑通通路的占位数据：1kHz 正弦 1 秒 + 静音
def make_test():
    t = np.arange(TARGET_FS, dtype=np.float64) / TARGET_FS
    return np.sin(2 * np.pi * 1000 * t)


def read_wav(path):
    with wave.open(path, "rb") as w:
        n_ch, sw, fs = w.getnchannels(), w.getsampwidth(), w.getframerate()
        raw = w.readframes(w.getnframes())
    if sw != 2:
        raise SystemExit(f"只支持 16bit WAV，当前是 {sw * 8}bit")
    x = np.frombuffer(raw, dtype="<i2").astype(np.float64)
    if n_ch == 2:
        x = x.reshape(-1, 2).mean(axis=1)
    return x, fs


def to_8k(x, fs):
    if fs == TARGET_FS:
        return x
    # The competition recording is 48 kHz, an exact 6:1 ratio.  Average each
    # six-sample block before decimation to suppress high-frequency aliasing.
    if fs == 48000:
        usable = (len(x) // 6) * 6
        return x[:usable].reshape(-1, 6).mean(axis=1)
    # Dependency-free fallback for other input rates.
    out_len = int(round(len(x) * TARGET_FS / fs))
    src_pos = np.arange(len(x), dtype=np.float64)
    dst_pos = np.arange(out_len, dtype=np.float64) * fs / TARGET_FS
    return np.interp(dst_pos, src_pos, x)


def compress(x, fs):
    # 语音峰均比高，峰值归一化后平均电平很低，这里按 20ms 包络把平均电平抬到 TARGET_RMS
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x / peak
    win = max(1, int(fs * 0.02))
    env = np.sqrt(np.convolve(x * x, np.ones(win) / win, mode="same"))
    gain = np.minimum(TARGET_RMS / np.maximum(env, 1e-9), GAIN_MAX)
    # First-order gain smoothing, equivalent to the previous lfilter call but
    # without requiring SciPy on the build computer.
    gain_smooth = np.empty_like(gain)
    prev = gain[0] if len(gain) else 1.0
    for i, value in enumerate(gain):
        prev = GAIN_SMOOTH * value + (1.0 - GAIN_SMOOTH) * prev
        gain_smooth[i] = prev
    gain = gain_smooth
    y = x * gain
    return y / max(np.max(np.abs(y)), 1e-9)


def quantize(x):
    peak = np.max(np.abs(x))
    if peak > 0:
        x = x / peak * PEAK_USE
    return np.clip(np.round(x * 127 + 128), 0, 255).astype(np.uint8)


def write_mif(samples, path):
    buf = np.full(ROM_DEPTH, SILENCE, dtype=np.uint8)
    used = min(len(samples), ROM_DEPTH)
    buf[:used] = samples[:used]
    with open(path, "w", encoding="ascii") as f:
        f.write(f"WIDTH=8;\nDEPTH={ROM_DEPTH};\n\n")
        f.write("ADDRESS_RADIX=UNS;\nDATA_RADIX=HEX;\n\nCONTENT BEGIN\n")
        for i, v in enumerate(buf):
            f.write(f"{i} : {v:02X};\n")
        f.write("END;\n")
    # 同目录再出一份纯十六进制，供仿真 $readmemh 使用
    with open(path[:-4] + ".hex", "w", encoding="ascii") as f:
        for v in buf:
            f.write(f"{v:02X}\n")
    return used


def write_preview(samples, path):
    s16 = np.clip((samples.astype(np.int16) - 128) * 256, -32768, 32767)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(TARGET_FS)
        w.writeframes(s16.astype("<i2").tobytes())


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    if len(sys.argv) < 2:
        print(__doc__)
        print("用法: python wav_to_voice_mif.py <人声.wav> [输出.mif]")
        print("      python wav_to_voice_mif.py --test")
        return
    if sys.argv[1] == "--test":
        x, label = make_test(), "测试音"
    else:
        x, fs = read_wav(sys.argv[1])
        x, label = to_8k(x, fs), os.path.basename(sys.argv[1])

    x = compress(x, TARGET_FS)
    q = quantize(x)

    out = sys.argv[2] if len(sys.argv) > 2 else os.path.join(here, "voice.mif")
    used = write_mif(q, out)
    write_preview(q[:used], os.path.join(here, "voice_preview.wav"))

    secs = used / TARGET_FS
    print(f"{label}: 8kHz/8bit 共 {used} 样本 = {secs:.2f} 秒")
    print(f"  {out}")
    print(f"  {os.path.join(here, 'voice_preview.wav')}  (先听这个确认音质)")
    if secs > 4.0:
        print(f"  注意: 超过 4 秒，需把 VOICE_SAMPLES 改成 {used} 并调整 ROM 深度")


if __name__ == "__main__":
    main()

"""程序合成音效：生成 audio/ 下的新音效（44.1 kHz / 16 bit / 立体声）。

风格和 docs/audio-brief.md 一致：暖、轻、像八音盒和玻璃，不要金属尖响、不要大混响。
每个音效是一个函数，返回单声道或立体声的 numpy 数组；最后统一按"最响的 100 ms"归一化到目标响度。

    .tmp_build/venv/bin/python tools/sfx_synth.py            # 全部重新生成
    .tmp_build/venv/bin/python tools/sfx_synth.py bounce shard  # 只生成这几个

需要 numpy。改完要跑 godot --headless --path . --import，否则游戏里还是旧的。
"""
import sys
import wave

import numpy as np

SR = 44100
RNG = np.random.default_rng(7)


# ---------------------------------------------------------------- 基础件

def t_axis(dur):
    return np.arange(int(SR * dur)) / SR


def env_ad(n, attack, decay_tau, hold=0.0):
    """attack 秒线性起音，hold 秒保持，之后按 decay_tau 指数衰减。"""
    t = np.arange(n) / SR
    e = np.exp(-np.maximum(t - attack - hold, 0.0) / decay_tau)
    if attack > 0:
        e *= np.clip(t / attack, 0.0, 1.0)
    return e


def fade_tail(x, dur=0.02):
    """尾巴最后 dur 秒淡到 0，免得咔哒。"""
    n = min(int(SR * dur), x.shape[0])
    ramp = np.linspace(1.0, 0.0, n)
    x = x.copy()
    if x.ndim == 1:
        x[-n:] *= ramp
    else:
        x[-n:] *= ramp[:, None]
    return x


def sine_sweep(dur, f0, f1, curve=1.0):
    """频率从 f0 滑到 f1（curve>1 前快后慢的指数感）。"""
    t = t_axis(dur)
    k = (t / dur) ** curve if dur > 0 else t
    f = f0 * (f1 / f0) ** k
    return np.sin(2 * np.pi * np.cumsum(f) / SR)


def noise(n):
    return RNG.uniform(-1.0, 1.0, n)


def onepole_lp(x, fc):
    """一阶低通。fc 可以是标量或逐采样数组。"""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    a = np.exp(-2 * np.pi * fc / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(x.shape[0]):
        acc = (1 - a[i]) * x[i] + a[i] * acc
        y[i] = acc
    return y


def onepole_hp(x, fc):
    return x - onepole_lp(x, fc)


def biquad_bp(x, fc, q):
    """带通（RBJ），fc 可逐采样变化。"""
    fc = np.broadcast_to(np.asarray(fc, dtype=float), x.shape)
    y = np.zeros_like(x)
    x1 = x2 = y1 = y2 = 0.0
    for i in range(x.shape[0]):
        w0 = 2 * np.pi * fc[i] / SR
        alpha = np.sin(w0) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * np.cos(w0), 1 - alpha
        yi = (b0 * x[i] + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x[i]
        y2, y1 = y1, yi
        y[i] = yi
    return y


def bell(dur, freq, decay=0.35, bright=1.0, inharm=(1.0, 2.0, 3.01, 4.2, 5.43)):
    """八音盒/小铃：几个略不谐和的泛音，高泛音衰减得更快。"""
    t = t_axis(dur)
    out = np.zeros_like(t)
    for k, ratio in enumerate(inharm):
        amp = (0.6 ** k) * (bright if k else 1.0)
        tau = decay / (1 + 0.9 * k)
        out += amp * np.sin(2 * np.pi * freq * ratio * t + RNG.uniform(0, 6.28)) * np.exp(-t / tau)
    out *= np.clip(t / 0.002, 0, 1)
    return out


def thump(dur, f0, f1, decay):
    """低频冲击：正弦从 f0 掉到 f1，指数衰减。"""
    return sine_sweep(dur, f0, f1, 0.35) * env_ad(int(SR * dur), 0.001, decay)


def crackles(dur, rate, decay=0.004, fc=3000, q=1.2, density_env=None):
    """随机的小噼啪：按 rate（个/秒）撒脉冲，再过带通。"""
    n = int(SR * dur)
    x = np.zeros(n)
    count = int(rate * dur)
    pos = RNG.integers(0, n, count)
    for p in pos:
        m = min(int(SR * decay * 6), n - p)
        x[p:p + m] += RNG.uniform(0.3, 1.0) * RNG.choice([-1, 1]) * np.exp(-np.arange(m) / (SR * decay))
    if density_env is not None:
        x *= density_env
    return biquad_bp(x, fc, q)


def pad(n, total):
    """补零到 total 个采样。"""
    if n.shape[0] >= total:
        return n[:total]
    return np.concatenate([n, np.zeros(total - n.shape[0])])


def mix(*parts):
    """叠加；每一层的尾巴先淡掉 5 ms，层在中途被截断时不留咔哒声。"""
    total = max(p.shape[0] for p in parts)
    return sum(pad(fade_tail(p, 0.005), total) for p in parts)


def at(x, offset, total):
    """把 x 放到 offset 秒处，总长 total 秒。"""
    out = np.zeros(int(SR * total))
    s = int(SR * offset)
    m = min(x.shape[0], out.shape[0] - s)
    out[s:s + m] = fade_tail(x[:m], 0.005)
    return out


def allpass(x, d, g=0.5):
    """Schroeder 全通：把梳状滤波的"金属嗡嗡声"打散。"""
    y = np.zeros_like(x)
    for i in range(x.shape[0]):
        xd = x[i - d] if i >= d else 0.0
        yd = y[i - d] if i >= d else 0.0
        y[i] = -g * x[i] + xd + g * yd
    return y


def room(x, wet=0.18, size=0.06, tail=0.25):
    """很小的房间感：几条梳状反馈延迟 + 两级全通扩散，左右声道用不同延迟做出宽度。返回立体声。
    干声先淡出尾巴：干声在末尾被硬切会在频谱上留一条竖线（咔哒声）。"""
    x = fade_tail(x, 0.012)
    out = []
    for side, delays in enumerate(([0.0297, 0.0371, 0.0411, 0.0437], [0.0313, 0.0353, 0.0397, 0.0451])):
        y = np.zeros(x.shape[0] + int(SR * tail))
        y[:x.shape[0]] += x
        wet_sig = np.zeros_like(y)
        for d in delays:
            d = int(SR * d * (size / 0.06))
            g = 0.5 ** (d / (SR * tail * 0.35))
            buf = np.zeros_like(y)
            src = np.zeros_like(y)
            src[:x.shape[0]] = x
            for i in range(d, y.shape[0]):
                buf[i] = src[i - d] + g * buf[i - d]
            wet_sig += buf
        for ap in ((0.005, 0.0017) if side == 0 else (0.0053, 0.0019)):
            wet_sig = allpass(wet_sig, int(SR * ap), 0.6)
        wet_sig = onepole_lp(wet_sig, 5000)
        wet_sig = fade_tail(wet_sig, 0.03)
        out.append(y + wet * wet_sig / len(delays))
    return np.stack(out, axis=1)


def loopable(x, xfade=0.25):
    """做成无缝循环：尾巴 xfade 秒等功率交叉淡化到开头。"""
    n = int(SR * xfade)
    head, body, tail = x[:n], x[n:-n] if n else x, x[-n:]
    k = np.linspace(0, 1, n)
    joined = tail * np.cos(k * np.pi / 2) + head * np.sin(k * np.pi / 2)
    return np.concatenate([joined, body])


# ---------------------------------------------------------------- 各个音效

def sfx_bounce():
    # 阶段 3/4 反弹：短促的"嗒"+ 一点带音高的回弹，像小木球弹在软木上。很常见，要轻。
    d = 0.22
    tick = biquad_bp(noise(int(SR * 0.03)), 2400, 1.5) * env_ad(int(SR * 0.03), 0.0005, 0.006)
    ping = sine_sweep(d, 780, 560, 0.3) * env_ad(int(SR * d), 0.001, 0.045)
    body = thump(0.1, 220, 120, 0.03)
    return room(mix(tick * 0.8, ping * 0.55, body * 0.5), wet=0.12, tail=0.15)


def sfx_smash():
    # 阶段 5 撞碎黑墙：闷的低频 + 砖石碎裂的噼啪 + 尾巴上掉落的碎屑。
    d = 0.7
    boom = thump(d, 95, 38, 0.16)
    crunch = biquad_bp(noise(int(SR * 0.25)), 1400, 0.8) * env_ad(int(SR * 0.25), 0.001, 0.05)
    dens = env_ad(int(SR * d), 0.0, 0.18)
    bits = crackles(d, 220, 0.003, 3200, 1.0, dens)
    tinkle = at(crackles(0.35, 40, 0.006, 5200, 3.0), 0.12, d)
    return room(mix(boom * 1.0, crunch * 0.7, bits * 0.9, tinkle * 0.5), wet=0.16, tail=0.3)


def sfx_stop():
    # 软垫急停：被垫子"噗"地接住，软、闷。
    d = 0.3
    n = int(SR * d)
    # 两级低通：一阶的斜率太缓，单级的话高频沙沙声太多，听起来像擦而不像"噗"。
    puff = onepole_lp(onepole_lp(noise(n), np.linspace(1500, 250, n)), 1200) * 2.0 * env_ad(n, 0.004, 0.06)
    body = thump(d, 140, 70, 0.07)
    return room(mix(puff * 0.9, body * 0.8), wet=0.08)


def sfx_shard():
    # 捡到小星星：两颗快速上行的小铃 + 一点亮晶晶的沙沙。连着捡时运行时升调。
    d = 0.45
    a = bell(d, 1318.5, 0.18, 0.7)                 # E6
    b = at(bell(d - 0.05, 1975.5, 0.22, 0.6), 0.05, d)  # B6
    n = int(SR * d)
    sparkle = onepole_hp(noise(n), 6000) * env_ad(n, 0.002, 0.05) * 0.25
    return room(mix(a * 0.6, b * 0.55, sparkle), wet=0.22, tail=0.3)


def sfx_warn():
    # 进入阶段 2 的预警："嘀嘀"两下，小二度不和谐，柔和但听得出"不妙"。
    d = 0.32
    out = np.zeros(int(SR * d))
    for k, off in enumerate((0.0, 0.13)):
        n = int(SR * 0.1)
        t = np.arange(n) / SR
        tone = (np.sin(2 * np.pi * 880 * t) + 0.7 * np.sin(2 * np.pi * 932.3 * t)) * env_ad(n, 0.003, 0.035)
        out += at(tone, off, d) * (1.0 if k == 0 else 0.85)
    return room(out, wet=0.1)


def sfx_gear():
    # 升到阶段 3/4：一股往上走的风声，告诉玩家"现在撞墙会弹开了"。
    d = 0.42
    n = int(SR * d)
    fc = np.geomspace(500, 2600, n)
    whoosh = biquad_bp(noise(n), fc, 2.0) * np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5
    shine = sine_sweep(d, 660, 990, 0.8) * env_ad(n, 0.12, 0.08) * 0.25
    return room(mix(whoosh, shine), wet=0.12)


def sfx_focus():
    # 切到聚光：一下轻的"咔"+ 往上收紧的音。
    d = 0.16
    n = int(SR * d)
    click = biquad_bp(noise(int(SR * 0.012)), 3500, 2.0) * env_ad(int(SR * 0.012), 0.0003, 0.002)
    glide = sine_sweep(d, 520, 1040, 0.6) * env_ad(n, 0.004, 0.05)
    return room(mix(click * 0.6, glide * 0.45), wet=0.1)


def sfx_scatter():
    # 切回散射：同一个"咔"，音往下散开。
    d = 0.18
    n = int(SR * d)
    click = biquad_bp(noise(int(SR * 0.012)), 3000, 2.0) * env_ad(int(SR * 0.012), 0.0003, 0.002)
    glide = sine_sweep(d, 900, 450, 0.6) * env_ad(n, 0.004, 0.06)
    return room(mix(click * 0.6, glide * 0.45), wet=0.12)


def sfx_aim():
    # 影鬼瞄准：0.6 秒越来越高、越来越急的嗡声，最后一刻最响（运行时按瞄准时间变调）。
    d = 0.6
    n = int(SR * d)
    t = np.arange(n) / SR
    f = 260 * (3.2 ** (t / d))
    tone = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(2 * np.pi * np.cumsum(f * 2.01) / SR)
    trem = 0.6 + 0.4 * np.sin(2 * np.pi * np.cumsum(6 + 18 * t / d) / SR)
    grow = (t / d) ** 1.6
    return room(tone * trem * grow * np.clip((d - t) / 0.01, 0, 1), wet=0.08)


def sfx_shot():
    # 影鬼开枪：短、闷、有点电子味的"啾"（不是枪声）。
    d = 0.24
    n = int(SR * d)
    zap = sine_sweep(d, 1100, 180, 0.4) * env_ad(n, 0.001, 0.05)
    hiss = onepole_lp(noise(n), 2500) * env_ad(n, 0.001, 0.02) * 0.3
    return room(mix(zap * 0.8, hiss), wet=0.12)


def sfx_meteor_warn():
    # 流星预警：1.1 秒，低沉的嗡鸣越来越响，上面一条往下落的哨音。
    d = 1.1
    n = int(SR * d)
    t = np.arange(n) / SR
    rumble = onepole_lp(noise(n), 160) * 3.0 * (t / d) ** 1.3
    whistle = sine_sweep(d, 1800, 500, 1.4) * 0.22 * (t / d) ** 2
    return fade_tail(room(mix(rumble, whistle), wet=0.15, tail=0.1), 0.01)


def sfx_meteor():
    # 流星落地：重的闷响 + 碎石。
    d = 0.75
    boom = thump(d, 80, 32, 0.2)
    crunch = onepole_lp(noise(int(SR * 0.3)), 1200) * env_ad(int(SR * 0.3), 0.001, 0.07)
    rocks = crackles(d, 120, 0.004, 1800, 0.9, env_ad(int(SR * d), 0.0, 0.25))
    return room(mix(boom * 1.1, crunch * 0.8, rocks * 0.8), wet=0.2, tail=0.35)


def sfx_checkpoint():
    # 检查点点亮：擦火柴的"嚓" + 一个暖的五度和音慢慢亮起。
    d = 0.9
    n = int(SR * 0.09)
    strike = biquad_bp(noise(n), np.linspace(2500, 4500, n), 1.0) * env_ad(n, 0.002, 0.03)
    c = at(bell(0.8, 523.25, 0.45, 0.5), 0.06, d)   # C5
    g = at(bell(0.8, 783.99, 0.4, 0.4), 0.1, d)     # G5
    return room(mix(strike * 0.7, c * 0.5, g * 0.4), wet=0.25, tail=0.4)


def sfx_door():
    # 铁门打开：沉的金属摩擦往上拖 + 最后"咚"一声落定。
    d = 0.95
    n = int(SR * 0.7)
    scrape = biquad_bp(noise(n), np.geomspace(300, 900, n), 6.0) * np.sin(np.pi * np.linspace(0, 1, n)) ** 0.8
    metal = np.zeros(n)
    t = np.arange(n) / SR
    for r in (1.0, 2.76, 5.4):
        metal += np.sin(2 * np.pi * 180 * r * t) * 0.15 / r
    metal *= np.sin(np.pi * np.linspace(0, 1, n))
    clunk = at(thump(0.3, 110, 60, 0.06), 0.65, d)
    return room(mix(scrape * 0.8, metal, clunk * 0.9), wet=0.22, tail=0.35)


def sfx_accel():
    # 踩到加速带：短促上扬的"呼"。
    d = 0.32
    n = int(SR * d)
    fc = np.geomspace(700, 3500, n)
    w = biquad_bp(noise(n), fc, 1.8) * env_ad(n, 0.02, 0.09)
    tone = sine_sweep(d, 440, 880, 0.7) * env_ad(n, 0.01, 0.07) * 0.3
    return room(mix(w, tone), wet=0.1)


def sfx_ui():
    # 按钮："嗒"，极短的木头声。
    d = 0.09
    n = int(SR * d)
    knock = sine_sweep(d, 1500, 900, 0.3) * env_ad(n, 0.0005, 0.012)
    click = biquad_bp(noise(n), 2800, 2.5) * env_ad(n, 0.0003, 0.004)
    return room(mix(knock * 0.6, click * 0.7), wet=0.05, tail=0.06)


def sfx_heart():
    # 低亮度的心跳："咚—咚"，很低很闷。
    d = 0.55
    a = thump(0.25, 75, 45, 0.05)
    b = at(thump(0.25, 65, 40, 0.06), 0.2, d)
    lp = onepole_lp(mix(a, b * 0.75), 400)
    return room(lp, wet=0.05, tail=0.05)


def sfx_wind():
    # 高速时的风声（循环）：粉红感的噪声过一个缓慢游移的带通。音量和音高由运行时跟速度走。
    d = 2.4
    n = int(SR * d)
    t = np.arange(n) / SR
    fc = 900 + 350 * np.sin(2 * np.pi * t / d) + 150 * np.sin(2 * np.pi * 3 * t / d)
    w = biquad_bp(noise(n), fc, 0.9)
    w = onepole_lp(w, 3000)
    st = np.stack([w, np.roll(w, int(SR * 0.37))], axis=1)
    return np.stack([loopable(st[:, 0]), loopable(st[:, 1])], axis=1)


def sfx_wake():
    # 正在照醒小人（循环）：温暖的微光音，两个略失谐的正弦加颤音。运行时音高随进度升高。
    d = 2.0
    t = t_axis(d)
    f = 392.0  # G4
    tone = np.sin(2 * np.pi * f * t) + 0.6 * np.sin(2 * np.pi * f * 1.5 * t) + 0.35 * np.sin(2 * np.pi * f * (1570 / 784) * t)
    trem = 0.75 + 0.25 * np.sin(2 * np.pi * 5 * t)
    shimmer = onepole_hp(noise(t.shape[0]), 7000) * 0.015
    x = tone * trem * 0.4 + shimmer
    st = np.stack([x, np.roll(x, 811)], axis=1)
    return st  # 2 秒正好是 5 Hz 颤音和各个泛音的整周期，首尾自然接得上


def sfx_cry():
    # 小人的哭声：八音盒往下落的小三度"呜——呜"，带一点气声。用来在黑暗里找人。
    d = 1.3
    a = bell(0.7, 880.0, 0.35, 0.4)            # A5
    b = at(bell(0.9, 739.99, 0.45, 0.35), 0.32, d)  # F#5
    n = int(SR * d)
    breath = onepole_lp(onepole_hp(noise(n), 900), 2500) * env_ad(n, 0.15, 0.25) * 0.12
    return room(mix(a * 0.6, b * 0.55, breath), wet=0.3, tail=0.4)


def sfx_crackle():
    # 影藤正在烧（循环）：细碎的噼啪 + 一点热气的嘶声。
    d = 1.6
    n = int(SR * d)
    pops = crackles(d, 70, 0.003, 2800, 0.9)
    hiss = onepole_lp(onepole_hp(noise(n), 1500), 4500) * 0.15
    x = loopable(pops + hiss, 0.2)
    return np.stack([x, np.roll(x, 1201)], axis=1)


def sfx_shield():
    # 守夜人的盾挡住噬光者：一声玻璃般的"叮"+ 被推开的风。
    d = 0.7
    ting = bell(d, 1567.98, 0.3, 0.9, (1.0, 2.32, 4.25, 6.63))  # G6
    n = int(SR * 0.4)
    push = biquad_bp(noise(n), np.geomspace(3000, 600, n), 1.5) * env_ad(n, 0.005, 0.1)
    return room(mix(ting * 0.6, push * 0.8), wet=0.25, tail=0.35)


# 名字 → (函数, 目标响度：最响 100 ms 的 RMS，dBFS)。常见的轻，少见的响；循环的最轻。
SFX = {
    "bounce": (sfx_bounce, -19.0),
    "smash": (sfx_smash, -13.0),
    "stop": (sfx_stop, -17.0),
    "shard": (sfx_shard, -17.0),
    "warn": (sfx_warn, -17.0),
    "gear": (sfx_gear, -20.0),
    "focus": (sfx_focus, -21.0),
    "scatter": (sfx_scatter, -21.0),
    "aim": (sfx_aim, -20.0),
    "shot": (sfx_shot, -17.0),
    "meteor_warn": (sfx_meteor_warn, -19.0),
    "meteor": (sfx_meteor, -13.0),
    "checkpoint": (sfx_checkpoint, -15.0),
    "door": (sfx_door, -15.0),
    "accel": (sfx_accel, -17.0),
    "ui": (sfx_ui, -18.0),
    "heart": (sfx_heart, -15.0),
    "wind": (sfx_wind, -20.0),
    "wake": (sfx_wake, -21.0),
    "cry": (sfx_cry, -19.0),
    "crackle": (sfx_crackle, -21.0),
    "shield": (sfx_shield, -15.0),
}


def normalize(x, target_db, peak_db=-3.0):
    mono = x.mean(axis=1) if x.ndim == 2 else x
    win = int(SR * 0.1)
    if mono.shape[0] <= win:
        loud = np.sqrt((mono ** 2).mean())
    else:
        loud = np.sqrt(np.convolve(mono ** 2, np.ones(win) / win, "valid").max())
    gain = 10 ** (target_db / 20) / max(loud, 1e-9)
    peak = np.abs(x).max() * gain
    limit = 10 ** (peak_db / 20)
    if peak > limit:
        gain *= limit / peak
    return x * gain


def write(path, x):
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())


def main(names):
    for name in names or SFX:
        fn, target = SFX[name]
        x = fn()
        if name not in ("wind", "wake", "crackle"):
            x = fade_tail(x)
        x = normalize(x, target)
        write("audio/%s.wav" % name, x)
        print("audio/%s.wav  %.2fs" % (name, x.shape[0] / SR))


if __name__ == "__main__":
    main(sys.argv[1:])

"""Oyunun özgün müziğini ve ses efektlerini sentezler (harici örnek kullanmaz).

Kullanım: python3 tools/make_audio.py assets/audio
Gereken: numpy, ffmpeg (libvorbis). Çıktı: .ogg dosyaları.
"""
import os
import subprocess
import sys
import wave

import numpy as np

SR = 44100
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
rng = np.random.default_rng(7)


def note_hz(n):  # MIDI nota → Hz
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, a=0.005, d=0.1, s=0.6, r=0.05):
    t = np.arange(n) / SR
    e = np.ones(n) * s
    ai = int(a * SR)
    di = int(d * SR)
    ri = int(r * SR)
    if ai:
        e[:ai] = np.linspace(0, 1, ai)
    if di:
        e[ai:ai + di] = np.linspace(1, s, len(e[ai:ai + di]))
    if ri and n > ri:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def lowpass(x, cutoff):
    # basit tek kutuplu alçak geçiren
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc = (1 - a) * x[i] + a * acc
        y[i] = acc
    return y


def saw(f, n, detune=0.0):
    t = np.arange(n) / SR
    out = 2 * ((t * f) % 1.0) - 1
    if detune:
        out = 0.5 * out + 0.5 * (2 * ((t * f * (1 + detune)) % 1.0) - 1)
    return out


def square(f, n, duty=0.5, vib=0.0):
    t = np.arange(n) / SR
    ph = t * f
    if vib:
        ph = np.cumsum(f * (1 + vib * np.sin(2 * np.pi * 5.5 * t))) / SR
    return np.where((ph % 1.0) < duty, 1.0, -1.0)


def kick(n):
    t = np.arange(n) / SR
    f = 50 + 120 * np.exp(-t * 30)
    ph = np.cumsum(f) / SR
    return np.sin(2 * np.pi * ph) * np.exp(-t * 9)


def snare(n):
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    tone = np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25)
    return (0.7 * noise * np.exp(-t * 18) + 0.4 * tone)


def hat(n, open_=False):
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    hp = noise - lowpass(noise, 6000)
    return hp * np.exp(-t * (12 if open_ else 60))


def write(name, x, stereo_width=0.0):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.89
    pcm = (x * 32767).astype(np.int16)
    tmp = os.path.join(OUT, name + ".wav")
    with wave.open(tmp, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(pcm.tobytes())
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", tmp, "-c:a", "libvorbis", "-q:a", "4",
                    os.path.join(OUT, name + ".ogg")], check=True)
    os.remove(tmp)
    print("yazıldı", name, round(len(x) / SR, 2), "sn")


# ------------------------------------------------------------------ müzik
def music():
    bpm = 140
    beat = 60 / bpm
    step = beat / 4  # 16'lık
    bars = 16
    n_total = int(round(bars * 4 * beat * SR))
    mix = np.zeros(n_total + SR)
    s_len = int(step * SR)

    def put(sig, start_step, gain):
        i = int(round(start_step * step * SR))
        mix[i:i + len(sig)] += sig * gain

    # Akorlar (La minör): Am F C G — her akor 1 ölçü, 4 ölçüde bir tekrar
    chords = [[57, 60, 64], [53, 57, 60], [48, 52, 55], [55, 59, 62]]
    roots = [45, 41, 48, 43]
    # Melodi (16'lık adımlar; None = sus), 2 ölçülük motifler
    mel_a = [76, None, 72, None, 74, None, 76, 79, None, 76, None, 74, 72, None, 69, None,
             72, None, 69, None, 72, 74, None, 72, 69, None, 67, None, 69, None, None, None]
    mel_b = [81, None, 79, 76, None, 76, 79, None, 81, None, 84, None, 83, 81, 79, None,
             79, None, 76, 74, None, 74, 76, None, 79, None, 76, None, 74, None, 72, None]

    for bar in range(bars):
        section = bar // 4  # 0: giriş, 1: melodi A, 2: melodi B, 3: A + tam davul
        ci = bar % 4
        base = bar * 16
        # Davul
        for s in range(16):
            if s % 4 == 0:
                put(kick(int(0.35 * SR)), base + s, 0.9)
            if section >= 1 and s in (4, 12):
                put(snare(int(0.25 * SR)), base + s, 0.45)
            if s % 2 == 0 or section == 3:
                put(hat(int(0.08 * SR)), base + s, 0.12 if s % 2 else 0.18)
            if section >= 2 and s == 14:
                put(hat(int(0.3 * SR), True), base + s, 0.12)
        # Bas: 8'lik oktav zıplaması
        for s in range(0, 16, 2):
            n = roots[ci] + (12 if s % 4 == 2 else 0)
            sig = lowpass(saw(note_hz(n), s_len * 2), 900) * env(s_len * 2, 0.003, 0.08, 0.5, 0.02)
            put(sig, base + s, 0.42)
        # Ped
        if section >= 1:
            ln = s_len * 16
            pad = sum(lowpass(saw(note_hz(n), ln, 0.004), 1600) for n in chords[ci])
            put(pad * env(ln, 0.08, 0.3, 0.7, 0.1), base, 0.07)
        # Arpej (giriş bölümünde melodi yerine)
        if section == 0 and bar >= 2:
            for s in range(16):
                n = chords[ci][s % 3] + 12
                sig = square(note_hz(n), s_len, 0.25) * env(s_len, 0.002, 0.05, 0.3, 0.02)
                put(lowpass(sig, 3500), base + s, 0.09)
        # Melodi
        if section >= 1:
            mel = mel_b if section == 2 else mel_a
            for s in range(16):
                n = mel[(bar % 2) * 16 + s]
                if n is None:
                    continue
                length = s_len * 2
                sig = square(note_hz(n), length, 0.5, vib=0.004) * env(length, 0.004, 0.08, 0.55, 0.04)
                put(lowpass(sig, 4200), base + s, 0.13)
                # yankı
                put(lowpass(sig, 2500), base + s + 3, 0.04)
    # Döngünün sonundan taşanı başa ekle (kesintisiz döngü)
    tail = mix[n_total:]
    mix[:len(tail)] += tail
    write("music", mix[:n_total])


# ------------------------------------------------------------------ efektler
def sweep(f0, f1, dur, wave_="square", decay=8.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f0 * (f1 / f0) ** (t / dur)
    ph = np.cumsum(f) / SR
    if wave_ == "square":
        sig = np.where((ph % 1) < 0.5, 1.0, -1.0)
    else:
        sig = np.sin(2 * np.pi * ph)
    return lowpass(sig, 5000) * np.exp(-t * decay) * env(n, 0.002, 0.0, 1.0, 0.02)


def sfx():
    write("jump", sweep(300, 760, 0.16, "square", 10))
    write("wall_jump", np.concatenate([sweep(420, 900, 0.09, "square", 6), sweep(640, 1300, 0.12, "square", 12)]))
    n = int(0.42 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    swoosh = (lowpass(noise, 1800) - lowpass(noise, 300)) * np.sin(np.pi * t / t[-1]) ** 2
    write("slide", swoosh)
    gem = np.concatenate([
        square(note_hz(n), int(0.06 * SR), 0.25) * env(int(0.06 * SR), 0.002, 0.03, 0.5, 0.01)
        for n in (84, 88, 91)
    ] + [square(note_hz(96), int(0.22 * SR), 0.25) * np.exp(-np.arange(int(0.22 * SR)) / SR * 14)])
    write("gem", lowpass(gem, 6000))
    write("land", kick(int(0.12 * SR)) * 0.8 + lowpass(rng.uniform(-1, 1, int(0.12 * SR)), 600) * np.exp(-np.arange(int(0.12 * SR)) / SR * 40) * 0.5)
    die = sweep(600, 70, 0.9, "square", 2.5)
    write("death", die)
    # Lav gürültüsü (döngü)
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    rumble = lowpass(lowpass(noise, 140), 140) * (0.7 + 0.3 * np.sin(2 * np.pi * t / 3.0))
    pops = np.zeros(n)
    for _ in range(9):
        i = rng.integers(0, n - 4000)
        m = 3000
        pops[i:i + m] += np.sin(2 * np.pi * rng.uniform(80, 180) * np.arange(m) / SR) * np.exp(-np.arange(m) / SR * 30)
    fade = int(0.05 * SR)
    sig = rumble * 3 + pops * 0.3
    sig[:fade] *= np.linspace(0, 1, fade)
    sig[-fade:] *= np.linspace(1, 0, fade)
    write("lava", sig)


os.makedirs(OUT, exist_ok=True)
sfx()
music()

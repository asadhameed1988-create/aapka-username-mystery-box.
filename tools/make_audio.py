"""Generates every sound in assets/audio from code (original, no third-party recordings).
    python3 tools/make_audio.py
Replace any file with a better recording of the same name whenever you like.
The music loop is then converted:  ffmpeg -i music_loop.wav -c:a libvorbis -q:a 3 music_loop.ogg
"""
import os
import wave

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
# D Hijaz scale (D Eb F# G A Bb C), the colour of much old Arabic music.
HIJAZ = [146.83, 155.56, 185.00, 196.00, 220.00, 233.08, 261.63, 293.66, 311.13, 369.99, 392.00, 440.00, 587.33]


def env(n, attack=0.004, decay=6.0):
    t = np.arange(n) / SR
    return np.minimum(1.0, t / attack) * np.exp(-decay * t)


def bell(freq, dur, decay=7.0):
    n = int(SR * dur)
    t = np.arange(n) / SR
    tone = np.sin(2 * np.pi * freq * t) + 0.45 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-9 * t) \
        + 0.25 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-14 * t)
    return tone * env(n, 0.003, decay)


def pluck(freq, dur, rng, damp=0.996):
    """Karplus-Strong string (oud-like)."""
    n = int(SR * dur)
    period = max(2, int(SR / freq))
    buf = rng.uniform(-1, 1, period)
    out = np.empty(n)
    for i in range(n):
        out[i] = buf[i % period]
        buf[i % period] = damp * 0.5 * (buf[i % period] + buf[(i + 1) % period])
    return out * env(n, 0.002, 1.2)


def noise_burst(dur, rng, decay, lowpass=0.35):
    n = int(SR * dur)
    x = rng.uniform(-1, 1, n)
    y = np.empty(n)
    acc = 0.0
    for i in range(n):
        acc += lowpass * (x[i] - acc)
        y[i] = acc
    return y * env(n, 0.001, decay)


def mix(length, parts):
    out = np.zeros(int(SR * length))
    for start, sig, gain in parts:
        a = int(SR * start)
        b = min(len(out), a + len(sig))
        out[a:b] += sig[: b - a] * gain
    return out


def save(name, sig, peak=0.7):
    sig = sig / max(1e-9, np.max(np.abs(sig))) * peak
    fade = int(SR * 0.004)
    sig[-fade:] *= np.linspace(1, 0, fade)
    data = (sig * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("%-12s %.2fs" % (name, len(sig) / SR))


def main():
    os.makedirs(OUT, exist_ok=True)
    rng = np.random.default_rng(1206)
    save("tap", mix(0.07, [(0, noise_burst(0.05, rng, 90, 0.6), 0.7), (0, bell(1700, 0.06, 60), 0.5)]), 0.45)
    save("turn", mix(0.10, [(0, noise_burst(0.08, rng, 55, 0.2), 1.0), (0, bell(420, 0.09, 40), 0.6)]), 0.55)
    save("wrong", mix(0.32, [(0, bell(155, 0.3, 12), 1.0), (0.09, bell(117, 0.22, 12), 1.0),
                             (0, noise_burst(0.12, rng, 30, 0.08), 0.5)]), 0.6)
    save("hint", mix(0.5, [(0, bell(880, 0.5, 8), 1.0), (0.05, bell(1318.5, 0.4, 10), 0.4)]), 0.5)
    save("clear", mix(0.9, [(0.00, bell(587.33, 0.7, 6), 1.0), (0.11, bell(739.99, 0.7, 6), 0.9),
                            (0.22, bell(880.00, 0.68, 5), 0.9)]), 0.65)
    save("award", mix(1.3, [(0, bell(440, 1.2, 4), 0.8), (0.02, bell(587.33, 1.2, 4), 0.8), (0.04, bell(739.99, 1.2, 4), 0.8),
                            (0.30, bell(1174.66, 0.9, 5), 0.6)]), 0.65)
    notes = [293.66, 311.13, 369.99, 392.00, 440.00, 587.33]
    parts = [(i * 0.13, pluck(f, 1.2, rng), 0.9) for i, f in enumerate(notes)]
    parts += [(0.75, bell(1174.66, 1.0, 3.5), 0.5), (0.80, bell(880.0, 1.0, 3.5), 0.4), (0, noise_burst(0.5, rng, 7, 0.05), 0.6)]
    save("open", mix(2.0, parts), 0.7)

    music()


def clink(freq, dur, rng):
    """One coin hit: bright inharmonic metal partials with a very short decay."""
    n = int(SR * dur)
    t = np.arange(n) / SR
    ratios = [1.0, 1.52, 2.33, 3.17, 4.08]
    sig = sum(np.sin(2 * np.pi * freq * r * t + rng.uniform(0, 6.28)) * np.exp(-(18 + 9 * k) * t) / (1 + k)
              for k, r in enumerate(ratios))
    return sig * np.minimum(1.0, t / 0.0008)


def coins():
    """A shower of coins: many clinks, dense at first, thinning out."""
    rng = np.random.default_rng(77)
    parts = []
    for i in range(46):
        when = (rng.uniform(0, 1) ** 1.8) * 1.5
        parts.append((when, clink(rng.uniform(2400, 5200), 0.35, rng), rng.uniform(0.35, 1.0)))
    parts.append((0, noise_burst(0.25, rng, 14, 0.5), 0.25))
    save("coins", mix(1.9, parts), 0.6)


def music():
    """Original slow, majestic piece in maqam Hijaz on D: string drone, daf (frame drum),
    oud plucks and a ney (reed flute) melody. Everything wraps around, so the loop is seamless."""
    rng = np.random.default_rng(634)
    beat = 60.0 / 72.0
    bars = 16
    length = bars * 4 * beat
    n = int(SR * length)
    t = np.arange(n) / SR
    dry = np.zeros(n)

    def place(sig, when, gain):
        idx = (int(SR * when) + np.arange(len(sig))) % n
        np.add.at(dry, idx, sig * gain)

    def strings(freq, dur):
        m = int(SR * dur)
        tt = np.arange(m) / SR
        out = np.zeros(m)
        for detune in (0.997, 1.0, 1.004):
            for k in range(1, 7):
                out += np.sin(2 * np.pi * freq * detune * k * tt + rng.uniform(0, 6.28)) / (k ** 1.6)
        swell = np.sin(np.pi * np.minimum(1.0, tt / dur)) ** 0.7
        return out * swell

    def dum():
        m = int(SR * 0.5)
        tt = np.arange(m) / SR
        freq = 52 + 46 * np.exp(-tt * 18)
        return np.sin(2 * np.pi * np.cumsum(freq) / SR) * np.exp(-tt * 7) + noise_burst(0.5, rng, 40, 0.05)[:m] * 0.6

    def tek():
        m = int(SR * 0.16)
        tt = np.arange(m) / SR
        return (noise_burst(0.16, rng, 45, 0.7)[:m] * 0.7 + np.sin(2 * np.pi * 960 * tt) * np.exp(-tt * 45) * 0.5)

    def ney(freq, dur):
        m = int(SR * dur)
        tt = np.arange(m) / SR
        vib = 1.0 + 0.006 * np.sin(2 * np.pi * 5.3 * tt) * np.minimum(1.0, tt / 0.35)
        phase = 2 * np.pi * np.cumsum(freq * vib) / SR
        tone = np.sin(phase) + 0.28 * np.sin(2 * phase) + 0.10 * np.sin(3 * phase)
        breath = noise_burst(dur, rng, 0.0001, 0.25)[:m] * 0.10
        shape = np.minimum(1.0, tt / 0.09) * np.minimum(1.0, (dur - tt) / 0.18)
        return (tone + breath) * shape

    D2, A2, D3, G2, Bb2, Eb2, G3, Bb3, Eb3 = 73.42, 110.0, 146.83, 98.0, 116.54, 77.78, 196.0, 233.08, 155.56
    D4, Eb4, Fs4, G4, A4, Bb4, C5, D5 = 293.66, 311.13, 369.99, 392.0, 440.0, 466.16, 523.25, 587.33
    # Harmony, 4 bars each:  D (home)  ->  G minor  ->  E-flat (the Hijaz colour)  ->  D
    chords = [(D2, A2, D3), (G2, D3, Bb2), (Eb2, Bb2, Eb3), (D2, A2, D3)]
    for c, chord in enumerate(chords):
        for f in chord:
            place(strings(f, 16 * beat + 1.5), c * 16 * beat, 0.07)
            place(strings(f * 2, 16 * beat + 1.5), c * 16 * beat, 0.08)

    # Daf: slow processional rhythm (dum . . tek | dum dum . tek), stronger on the first beat of each 4 bars.
    for bar in range(bars):
        base = bar * 4 * beat
        place(dum(), base, 0.55 if bar % 4 == 0 else 0.4)
        place(tek(), base + 1.5 * beat, 0.42)
        place(dum(), base + 2.0 * beat, 0.3)
        place(dum(), base + 2.5 * beat, 0.22)
        place(tek(), base + 3.0 * beat, 0.46)
        if bar % 2 == 1:
            place(tek(), base + 3.5 * beat, 0.22)

    # Oud: broken chords on the off-beats.
    oud_notes = [(D3, A2 * 2, D4, Fs4), (G3, Bb3, D4, G4), (Eb3, G3, Bb3, Eb4), (D3, Fs4 / 2, A2 * 2, D4)]
    for bar in range(bars):
        notes = oud_notes[bar // 4]
        for k, slot in enumerate((0.5, 1.0, 2.5, 3.5)):
            place(pluck(notes[(k + bar) % 4], 2.2, rng, 0.9972), (bar * 4 + slot) * beat, 0.55)

    # Ney melody (beats, pitch). Rests are left for breathing, as a real player would.
    phrase_a = [(2, A4), (1, Bb4), (1, A4), (2, G4), (2, Fs4), (1, Eb4), (1, Fs4), (2, G4), (1, Fs4), (1, Eb4), (2, D4)]
    phrase_b = [(2, D5), (1, C5), (1, Bb4), (3, A4), (1, None), (1, G4), (1, A4), (2, Bb4), (1, A4), (1, G4), (2, Fs4)]
    phrase_c = [(3, G4), (1, Bb4), (2, A4), (2, G4), (1, Fs4), (1, Eb4), (2, D4), (4, None)]
    phrase_d = [(1, D4), (1, Eb4), (1, Fs4), (1, G4), (3, A4), (1, None), (1, Bb4), (1, A4), (1, G4), (1, Fs4), (4, D4)]
    when = 0.0
    for phrase in (phrase_a, phrase_b, phrase_c, phrase_d):
        for beats, freq in phrase:
            if freq is not None:
                place(ney(freq, beats * beat * 0.97), when * beat, 0.62)
            when += beats

    # Hall reverb by circular convolution (keeps the loop seamless); slightly different left and right.
    spectrum = np.fft.rfft(dry)
    channels = []
    for seed in (1, 2):
        r = np.random.default_rng(seed)
        m = int(SR * 2.4)
        ir = r.normal(0, 1, m) * np.exp(-np.arange(m) / SR * 2.6)
        ir[: int(SR * 0.012)] = 0.0
        full = np.zeros(n)
        full[:m] = ir / np.sqrt(np.sum(ir ** 2))
        wet = np.fft.irfft(spectrum * np.fft.rfft(full), n)
        channels.append(dry + 0.55 * wet)
    stereo = np.stack(channels, axis=1)
    stereo = stereo / np.max(np.abs(stereo)) * 0.6
    with wave.open(os.path.join(OUT, "music_loop.wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((stereo * 32767).astype("<i2").tobytes())
    print("%-12s %.2fs (stereo loop)" % ("music_loop", length))


if __name__ == "__main__":
    import sys
    if len(sys.argv) > 1 and sys.argv[1] == "coins":
        coins()
    else:
        main()

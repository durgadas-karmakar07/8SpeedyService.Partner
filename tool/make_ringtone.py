"""Regenerates the original 8Speedy job-alert ringtone (no samples, pure synthesis).

Usage (needs numpy + ffmpeg):
    python tool/make_ringtone.py speedy_ring.wav
    ffmpeg -y -i speedy_ring.wav -c:a libvorbis -q:a 5 android/app/src/main/res/raw/speedy_ring.ogg
"""
import numpy as np, wave, sys

SR = 44100
def env_exp(n, decay):
    t = np.arange(n) / SR
    return np.exp(-t * decay)

def mallet(freq, dur, vel=1.0):
    n = int(dur * SR); t = np.arange(n) / SR
    # marimba-like partials (1x, 3.93x, 9.8x) + soft attack click
    s = (np.sin(2*np.pi*freq*t) * env_exp(n, 5.5)
         + 0.35*np.sin(2*np.pi*freq*3.93*t) * env_exp(n, 16)
         + 0.12*np.sin(2*np.pi*freq*9.8*t) * env_exp(n, 38))
    atk = np.minimum(1, t / 0.004)
    return vel * s * atk

def pluck_saw(freq, dur, vel=0.25):
    n = int(dur * SR); t = np.arange(n) / SR
    saw = sum(np.sin(2*np.pi*freq*k*t)/k for k in range(1, 8))
    return vel * saw * env_exp(n, 9) * np.minimum(1, t/0.01)

def kick(dur=0.35, vel=0.9):
    n = int(dur * SR); t = np.arange(n) / SR
    f = 110*np.exp(-t*18) + 45
    ph = 2*np.pi*np.cumsum(f)/SR
    return vel*np.sin(ph)*env_exp(n, 9)

def hat(dur=0.06, vel=0.12):
    n = int(dur*SR)
    rng = np.random.default_rng(8)
    noise = rng.standard_normal(n)
    noise = np.diff(np.concatenate([[0], noise]))  # crude high-pass
    return vel*noise*env_exp(n, 70)

def note(name):
    names = {'C':-9,'C#':-8,'D':-7,'D#':-6,'E':-5,'F':-4,'F#':-3,'G':-2,'G#':-1,'A':0,'A#':1,'B':2}
    p, o = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[p] + 12*(o-4)) / 12)

bpm = 150
e = 60/bpm/2          # eighth note
total = e*16 + 0.55   # two bars + breathing gap before the loop repeats
out = np.zeros(int(total*SR) + SR)

def put(sig, at):
    i = int(at*SR); out[i:i+len(sig)] += sig

melody = ['E5','G#5','B5','E6','D#6','B5','G#5','B5',
          'C#6','E6','G#6','F#6','E6','B5','G#5','E6']
vels   = [1,.8,.85,1,.9,.75,.7,.8, 1,.85,1,.9,.95,.75,.7,1.1]
for i,(n,v) in enumerate(zip(melody, vels)):
    put(mallet(note(n), 0.9, v), i*e)
    put(mallet(note(n)*2, 0.35, v*0.18), i*e)          # sparkle octave
# bass pluck on beats
for i,b in enumerate(['E3','E3','C#3','B2']):
    put(pluck_saw(note(b), e*3.6, 0.28), i*e*4)
for i in range(4):
    put(kick(), i*e*4)
for i in range(16):
    put(hat(vel=0.045 if i%2 else 0.025), i*e + e*0.5)

# short delay (echo) for width-feel in mono
d = int(e*1.5*SR)
echo = np.zeros_like(out); echo[d:] = out[:-d]*0.22
out = out + echo
out = out[:int(total*SR)]
# fade tail so the loop point is click-free
fade = int(0.05*SR); out[-fade:] *= np.linspace(1,0,fade)
out[:200] *= np.linspace(0,1,200)
# soft limiter + normalise
out = np.tanh(out*1.25)
out = out / np.max(np.abs(out)) * 0.93
pcm = (out*32767).astype(np.int16)
with wave.open(sys.argv[1], 'wb') as w:
    w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(pcm.tobytes())
print("seconds", round(len(pcm)/SR, 2))

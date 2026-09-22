# Verification

The Clouds addition was tested with Lua 5.3 and SuperCollider 3.13 on Linux ARM64,
using Norns source `42df84420774ef4d0961cf37946ed30e4078920f` and Rings/Clouds
plugins compiled from okyeron/mi-UGens `e340375aa4bde839c73c18a94296426c76ea08b1`.
No Norns hardware was connected. Realtime CPU load, audio inputs and physical
encoder interaction still need a hardware smoke test.

From the repository root:

```sh
find . -name '*.lua' -exec luac -p {} +
lua test/controls.lua /path/to/norns
python3 test/audio.py /path/to/mi-ugens /tmp/krill-clouds-audio
```

The Lua test uses the real Norns parameter classes and Krill modulation/GUI code,
with hardware APIs stubbed. It covers defaults, ranges, option indexing, PSET
round trips, a matrix patch, both sequencing menus and full parameter registration.
It also drives E2/E3 through Krill's real encoder handler for every Clouds control,
including coarse adjustment, limits and the existing stepped controls.

The audio test requires Linux `sclang`, `scsynth`, NumPy and SciPy. The plugin
directory must contain both `.sc` classes and compatible compiled `.so` plugins;
do not use Norns ARM32 binaries on another architecture. The default server plugin
path is `/usr/lib/SuperCollider/plugins` (adjust it in the test on other distros).
It compiles the full engine class with a minimal CroneEngine stub and extracts the
actual SynthDef for offline rendering through the real MI plugins. It verifies:

- One Rings instance, one Clouds instance and exactly two output channels.
- Non-silent, finite and bounded audio in all four modes, lofi and extreme settings.
- Bypass matches dry mix, and the wet processor changes the sound.
- Frozen grains continue after the source is silenced; an unfrozen buffer fades.
- A synthetic stereo input reaches Clouds independently of Rings, can be muted,
  mixes with Rings, preserves stereo and can be frozen. No microphone audio is recorded.

The test writes WAVs, a SuperCollider log and `results.json` to the specified
temporary output folder. It does not open an audio device. It does not exercise
the Norns OSC command transport or realtime scheduling.

On Norns, finish verification by switching between original Krill and Krill Clouds,
trying both sequencer modes, adjusting `cld mix`, freezing/unfreezing a phrase,
patching an LFO to `cld pos`, and saving/loading a named KRILL DATA preset.
Start with granular mode and check CPU before trying spectral mode.

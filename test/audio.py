"""Compile the full engine class and render its actual SynthDef through real plugins.

Usage: python3 test/audio.py /path/to/plugin-and-class-directory /tmp/test-output
Requires sclang, scsynth, numpy and scipy. The first directory must contain the
MiRings/MiClouds .sc classes and platform-compatible plugin binaries (recursive).
CroneEngine is stubbed for class compilation; DSP is not mocked. No audio device
is opened. This checks offline audio, not Norns realtime CPU or hardware I/O.
"""
import json
import os
from pathlib import Path
import subprocess
import sys

import numpy as np
from scipy.io import wavfile

plugins = Path(sys.argv[1]).resolve()
out = Path(sys.argv[2]).resolve()
out.mkdir(parents=True, exist_ok=True)
repo = Path(__file__).resolve().parents[1]
source = (repo / "lib/Engine_KrillClouds.sc").read_text()
classes = out / "classes"
classes.mkdir(exist_ok=True)
(classes / "CroneEngine.sc").write_text("CroneEngine { var <context; }\n")
(classes / "Engine_KrillClouds.sc").write_text(source)
config = out / "sclang.yaml"
config.write_text("includePaths:\n" + "".join("  - " + json.dumps(str(p)) + "\n" for p in (classes, plugins)) + "excludePaths: []\n")
synth = source[source.index("SynthDef("):source.index("}).add;") + len("})")]

# A synthetic stereo microphone signal; no hardware or speech is recorded.
t = np.arange(8 * 48000) / 48000
input_samples = np.column_stack((0.15 * np.sin(2 * np.pi * 220 * t),
                                 0.1 * np.sin(2 * np.pi * 330 * t)))
input_samples[t >= 2.5] = 0
wavfile.write(out / "input.wav", 48000, input_samples.astype(np.float32))

cases = {
    "dry": {"clouds_mix": 0},
    "bypass": {"clouds_mix": 1, "clouds_enabled": 0},
    "grain": {"clouds_mix": 1},
    "stretch": {"clouds_mix": 1, "clouds_mode": 1},
    "loop": {"clouds_mix": 1, "clouds_mode": 2},
    "spectral": {"clouds_mix": 1, "clouds_mode": 3},
    "lofi": {"clouds_mix": 1, "clouds_lofi": 1},
    "freeze": {"clouds_mix": 1, "clouds_reverb": 0, "clouds_feedback": 0},
    "unfrozen": {"clouds_mix": 1, "clouds_reverb": 0, "clouds_feedback": 0},
    "extreme": {"clouds_mix": 1, "clouds_feedback": 1, "clouds_gain": 8, "clouds_reverb": 1, "clouds_density": 1},
    "mic_off": {"amp": 0, "clouds_input": 0, "clouds_mix": 1},
    "mic_dry": {"amp": 0, "clouds_input": 1, "clouds_mix": 0},
    "mic_wet": {"amp": 0, "clouds_input": 1, "clouds_mix": 1},
    "mic_and_rings": {"clouds_input": 1, "clouds_mix": 1},
    "mic_freeze": {"amp": 0, "clouds_input": 1, "clouds_mix": 1, "clouds_reverb": 0, "clouds_feedback": 0},
    "mic_unfrozen": {"amp": 0, "clouds_input": 1, "clouds_mix": 1, "clouds_reverb": 0, "clouds_feedback": 0},
}
script = """(
var def, options, cases;
def = %s;
if(def.children.count { |ugen| ugen.class == MiRings } != 1) { Error("expected one Rings instance").throw };
if(def.children.count { |ugen| ugen.class == MiClouds } != 1) { Error("expected one Clouds instance").throw };
if(def.children.detect { |ugen| ugen.class == Out }.inputs.size != 3) { Error("output must be stereo").throw };
options = ServerOptions.new.numOutputBusChannels_(2).numInputBusChannels_(2).sampleRate_(48000).blockSize_(64);
options.ugenPluginsPath = %s;
cases = [
%s
];
Routine {
  cases.do { |item|
    var score, done = false;
    score = List.new;
    score.add([0, [\\d_recv, def.asBytes]]);
    score.add([0.01, [\\s_new, \\KrillCloudsSynth, 1000, 0, 0,
      \\out, 0, \\frequency, 60, \\internal_exciter, 1, \\trigger_mode, 0,
      \\trig, 0, \\gate, 0, \\env_active, 0, \\engine_mode, 2,
      \\rings_structure_max, 0.5, \\rings_brightness_max, 0.8] ++ item[1]]);
    6.do { |i|
      score.add([0.1 + (i * 0.4), [\\n_set, 1000, \\trig, 1, \\frequency, 60 + (i %% 3 * 4)]]);
      score.add([0.11 + (i * 0.4), [\\n_set, 1000, \\trig, 0]]);
    };
    if((item[0] == "freeze") or: {item[0] == "mic_freeze"}) { score.add([2.4, [\\n_set, 1000, \\clouds_freeze, 1]]) };
    // Remove the Rings input after capture; Clouds must keep its frozen audio.
    score.add([2.5, [\\n_set, 1000, \\amp, 0]]);
    score.add([7.9, [\\n_free, 1000]]);
    Score(score.asArray.sort { |a, b| a[0] < b[0] }).recordNRT(
      outputFilePath: %s +/+ (item[0] ++ ".wav"),
      inputFilePath: %s,
      sampleRate: 48000, headerFormat: "WAV", sampleFormat: "float",
      options: options, duration: 8,
      action: { |exitCode| if(exitCode != 0) { 1.exit }; done = true }
    );
    while { done.not } { 0.1.wait };
  };
  "PASS: engine class compiled, stereo graph built, all audio cases rendered".postln;
  0.exit;
}.play;
)
""" % (
    synth,
    json.dumps(str(plugins) + ":/usr/lib/SuperCollider/plugins"),
    ",\n".join('["' + name + '", [' + ", ".join("\\" + key + ", " + str(value) for key, value in settings.items()) + "]]" for name, settings in cases.items()),
    json.dumps(str(out)),
    json.dumps(str(out / "input.wav")),
)
script_path = out / "render.scd"
script_path.write_text(script)
env = dict(os.environ, QT_QPA_PLATFORM="offscreen", QTWEBENGINE_DISABLE_SANDBOX="1")
with (out / "render.log").open("w") as log:
    subprocess.run(["sclang", "-D", "-l", str(config), str(script_path)], env=env, stdout=log, stderr=subprocess.STDOUT, check=True, timeout=120)
log_text = (out / "render.log").read_text()
assert "ERROR" not in log_text and "FAILURE IN SERVER" not in log_text, log_text[-5000:]
audio = {}
report = {}
for name in cases:
    rate, samples = wavfile.read(out / (name + ".wav"))
    assert rate == 48000 and samples.ndim == 2 and samples.shape[1] == 2, name
    assert np.isfinite(samples).all(), name + ": non-finite audio"
    peak = float(np.max(np.abs(samples)))
    rms = float(np.sqrt(np.mean(samples.astype(float) ** 2)))
    assert peak <= 1.001, (name, peak)
    if name == "mic_off":
        assert peak < 1e-7, "disabled mic send must stay silent with Rings muted"
    else:
        assert rms > 1e-5, (name, rms)
    audio[name] = samples
    report[name] = {"peak": peak, "rms": rms}
assert np.max(np.abs(audio["dry"] - audio["bypass"])) < 1e-6, "bypass must match dry mix"
assert np.sqrt(np.mean((audio["grain"] - audio["dry"]) ** 2)) > 1e-4, "wet path must change the sound"
frozen_tail = np.sqrt(np.mean(audio["freeze"][5*48000:7*48000] ** 2))
unfrozen_tail = np.sqrt(np.mean(audio["unfrozen"][5*48000:7*48000] ** 2))
assert frozen_tail > 1e-4 and frozen_tail > unfrozen_tail * 10, (frozen_tail, unfrozen_tail)
assert np.sqrt(np.mean((audio["mic_wet"] - audio["mic_dry"]) ** 2)) > 1e-3
assert np.sqrt(np.mean((audio["mic_and_rings"] - audio["mic_wet"]) ** 2)) > 1e-5
assert np.sqrt(np.mean((audio["mic_dry"][:, 0] - audio["mic_dry"][:, 1]) ** 2)) > 1e-3, "preserve stereo input"
mic_frozen = np.sqrt(np.mean(audio["mic_freeze"][5*48000:7*48000] ** 2))
mic_unfrozen = np.sqrt(np.mean(audio["mic_unfrozen"][5*48000:7*48000] ** 2))
assert mic_frozen > 1e-4 and mic_frozen > mic_unfrozen * 10
(out / "results.json").write_text(json.dumps(report, indent=2) + "\n")
print("PASS: all four modes, lofi, finite bounded stereo audio, dry bypass, wet processing and freeze sustain")
print("PASS: direct stereo mic input, mute, wet processing, Rings blending and microphone freeze")
print(json.dumps(report, indent=2))

# Orbit Breaker original audio

The source is `generate_audio.py`: original D-minor 120 BPM composition, layered
transients, resonant metal, filtered noise, FM energy, stereo pads and delay.
No external recordings, samples, songs, voice models or paid services are used.
The resulting assets are created for this project, with provenance in `manifest.json`.

Run offline generation with Python, numpy and soundfile (libsndfile/Vorbis).
These are production tools, not game runtime dependencies. All randomness belongs
to the generator's own fixed seed. The game never synthesizes these files.
The manifest maps every cue to its variants and mix settings and records hashes.
Vorbis container serial numbers may differ on regeneration; waveform generation
is deterministic. Rebuilding audio requires renewed import/export validation.

Only `assets/audio/` is exported. This source folder and the authoring manifest
are excluded from Windows/Web packages. Quality and human listening acceptance
must be reported separately from successful generation and technical checks.

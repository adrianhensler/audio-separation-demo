# Audio Separation Demo

An interactive demonstration of AI-powered audio generation, mixing, and separation.

## Two Demos

### 🎤 Speech & Environmental Sounds (Experiment)
Mixing speech (TTS) with environmental sounds (dogs barking, traffic) to see how Demucs handles non-musical audio.

**[View Demo](https://adrianhensler.github.io/audio-separation-demo/)**

### 🎼 1812 Overture with Opera Singer (Music)
Orchestral music with cannons, opera vocals, percussion, and bass - showing Demucs working as intended with actual musical elements!

**[View Demo](https://adrianhensler.github.io/audio-separation-demo/music-separation.html)**

## What It Does

1. **Generate** - AI-generated audio clips (speech via MiniMax TTS, music via Stable Audio)
2. **Mix** - Combine multiple audio sources into one track
3. **Separate** - Use Demucs to split the mixed audio back into stems

## Technologies

- **MiniMax Speech-02-Turbo** - Text-to-speech generation
- **Stable Audio Open 1.0** - Environmental sound generation
- **Demucs (htdemucs)** - Audio source separation
- **ffmpeg** - Audio mixing

# Lud-WS Multi-MCU Project
Ludus WorkStation
Progetto orchestrato con 9 MCU indipendenti che comunicano via seriale per un sistema di sintesi e processing audio analogico e controllo digitale.

## 📦 Componenti MCU

| Repository | Ruolo | MCU |
|-----------|-------|-----|
| [Lud-WS-Display](https://github.com/ludus108/Lud-WS-Display) | Display / SD Mem | ESP32s3 |
| [Lud-WS-Ctrl](https://github.com/ludus108/Lud-WS-Ctrl) | Ctrl Pots / Keyboard | Pi Pico |
| [Lud-WS-Router](https://github.com/ludus108/Lud-WS-Router) | Hub comunicazione seriale | Pi Pico |
| [Lud-WS-SynthA_M](https://github.com/ludus108/Lud-WS-SynthA_M) | PoliSynth A - Main voce 1 | RP2040 |
| [Lud-WS-SynthA_V](https://github.com/ludus108/Lud-WS-SynthA_V) | PoliSynth A - Voci 2,3/4,5 | RP2040 |
| [Lud-WS-SynthB](https://github.com/ludus108/Lud-WS-SynthB) | Para/Mono Synth B | RP2040 |
| [Lud-WS-Teensy](https://github.com/ludus108/Lud-WS-Teensy) | Sampler & Trakcs | Teensy 4.1 |
| [Lud-WS-Mod](https://github.com/ludus108/Lud-WS-Mod) | Moduli effetti/controllo | Pi Pico |
| [Lud-WS-Power](https://github.com/ludus108/Lud-WS-Power) | Gestione alimentazione | LgxF328 |

## 🚀 Quick Start

### Clone con Submodules
```bash
git clone https://github.com/ludus108/Lud-WS
cd Lud-WS
git submodule update --init --recursive

# Lud-WS Multi-MCU Project

Progetto orchestrato con 9 MCU indipendenti che comunicano via seriale per un sistema di sintesi audio e controllo.

## 📦 Componenti MCU

| Repository | Ruolo | MCU |
|-----------|-------|-----|
| [Lud-WS-Display](https://github.com/ludus108/Lud-WS-Display) | Interfaccia utente / Display | TBD |
| [Lud-WS-Ctrl](https://github.com/ludus108/Lud-WS-Ctrl) | Controller principale | TBD |
| [Lud-WS-Router](https://github.com/ludus108/Lud-WS-Router) | Hub comunicazione seriale | TBD |
| [Lud-WS-SynthA_M](https://github.com/ludus108/Lud-WS-SynthA_M) | Sintetizzatore A - Modulation | TBD |
| [Lud-WS-SynthA_V](https://github.com/ludus108/Lud-WS-SynthA_V) | Sintetizzatore A - Voice | TBD |
| [Lud-WS-SynthB](https://github.com/ludus108/Lud-WS-SynthB) | Sintetizzatore B | TBD |
| [Lud-WS-Teensy](https://github.com/ludus108/Lud-WS-Teensy) | Audio processing | Teensy |
| [Lud-WS-Mod](https://github.com/ludus108/Lud-WS-Mod) | Moduli effetti/controllo | TBD |
| [Lud-WS-Power](https://github.com/ludus108/Lud-WS-Power) | Gestione alimentazione | TBD |

## 🚀 Quick Start

### Clone con Submodules
```bash
git clone https://github.com/ludus108/Lud-WS
cd Lud-WS
git submodule update --init --recursive

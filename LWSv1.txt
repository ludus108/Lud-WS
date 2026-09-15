# LWSv1 — LUD-WS Serial Protocol

**Versione corrente:** 1.1
**Stato:** stabile, in uso su tutti i nodi (Display, Router, MCU)
**Autore:** progetto LUD-WS
**Hardware target:** ESP32-S3 (Display), RP2350 (Router), vari (nodi)

---

## 1. Panoramica

LWS (LUD-WS Serial) è un protocollo seriale **proprietario** sviluppato per il
progetto LUD-WS. Non è uno standard pubblico: è definito e mantenuto
internamente e condiviso da tutti i firmware del sistema tramite
`serial_protocol.h`.

Il protocollo serve a far comunicare:

- **Display** (ESP32-S3, master del sistema)
- **Router** (RP2350, bridge seriale/MIDI)
- **Nodi** (Synth A1/A2/A3, Synth B, Ctrl, Mod, Teensy, Power)

Tutti i nodi sono identificati da un **carattere ASCII** e comunicano su
UART a 115200 8N1. Il Display è l'unico che avvia la discovery; gli altri
nodi rispondono.

### Topologia

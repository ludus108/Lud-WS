# Changelog - Lud-WS Multi-MCU Project

Tutte le modifiche notevoli a questo progetto sono documentate in questo file.

Il formato è basato su [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
e questo progetto segue [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.0.9] - 2026-09-13

### Added
- Repository principale Lud-WS creato
- Struttura progetto multi-MCU con 9 componenti
- Configurazione submodules per coordinamento repository
- Documentazione architettura sistema

### Components
- **Lud-WS-Display** (v0.0.9): Driver display ESP32s3
- **Lud-WS-Ctrl** (v0.0.9): Controllo potenziometri e tastiera
- **Lud-WS-Router** (v0.0.9): Hub comunicazione seriale
- **Lud-WS-SynthA_M** (v0.0.9): PoliSynth A - Voce principale
- **Lud-WS-SynthA_V** (v0.0.9): PoliSynth A - Voci aggiuntive
- **Lud-WS-SynthB** (v0.0.9): Para/Mono Synth B
- **Lud-WS-Teensy** (v0.0.9): Sampler e Tracks
- **Lud-WS-Mod** (v0.0.9): Moduli effetti/controllo
- **Lud-WS-Power** (v0.0.9): Gestione alimentazione

### Known Issues
- Comunicazione seriale da ottimizzare
- Latenza tra MCU da ridurre

---

## Template per versioni future

## [X.X.X] - YYYY-MM-DD

### Added
- Nuove feature

### Changed
- Modifiche esistenti

### Fixed
- Correzioni bug

### Removed
- Feature rimosse

### Security
- Fix di sicurezza

---

**Nota**: Per dettagli specifici di ogni componente, consulta il CHANGELOG del rispettivo repository.
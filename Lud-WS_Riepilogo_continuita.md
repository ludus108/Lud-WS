================================================================================
LUD-WS — RIEPILOGO DI CONTINUITÀ (MIGRAZIONE PLATFORMIO)
================================================================================
Documento autocontenuto. Incollalo come primo messaggio in una nuova chat
per riprendere il lavoro da dove è stato interrotto.

Ultimo aggiornamento: 2026-10-17
Focus sessione: migrazione completa da Arduino IDE 2 a PlatformIO + VS Code,
               con setup workspace multi-root, Copilot Pro, dumpStatus() di
               debug, ottimizzazione spazio su C:.
================================================================================


-------------------------------------------------------------------------------
0. STRUTTURA REPOSITORY
-------------------------------------------------------------------------------
	Lud-WS/
	├── Lud-WS.code-workspace     ← workspace multi-root VS Code (RINOMINATO)
	├── Lud-WS-Display/           ← ESP32-S3
	├── Lud-WS-Router/            ← RP2350 (Pico 2)
	├── Lud-WS-Ctrl/              ← RP2040 (Pico)
	├── Lud-WS-Mod/               ← (da migrare)
	├── Lud-WS-SyntA_M/           ← RP2350
	├── Lud-WS-SynthA_V/          ← RP2350 (da migrare)
	├── Lud-WS-SynthA_V2/         ← RP2350 (da migrare)
	├── Lud-WS-SynthB/            ← RP2350
	├── Lud-WS-Teensy/            ← Teensy 4.1
	└── Lud-WS-Power/             ← LGT8F328P

Bus: LWS v1.1, frame [SENDER][SEQ][CMD][LEN][PAYLOAD][CRC8][&][!].


-------------------------------------------------------------------------------
1. AMBIENTE DI SVILUPPO
-------------------------------------------------------------------------------
- OS: Windows 11, cartella utente `C:\Users\User` (in Explorer appare "Utenti")
- VS Code + estensione PlatformIO IDE (NON pioarduino-ide, disabilitata)
- GitHub Copilot Pro attivo (contesto @workspace funzionante)
- Git portable in `C:\PortableGit\cmd\git.exe` (PATH utente impostato)
- PlatformIO Core 6.2.0, Python 3.11.7

CONFIGURAZIONE PLATFORMIO (importante):
- `.platformio` packages/toolchain → D:\platformio (~9 GB, risparmiati su C:)
- `.platformio\penv` (Python) → rimane in C:\Users\User\.platformio\ (~150 MB)
- Variabile d'ambiente utente: `PLATFORMIO_CORE_DIR = D:\platformio`
- Long paths Windows abilitati (necessario per Arduino 3.3.12):
  Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWORD
- `git.path` in settings.json: "D:\\PortableGit\\cmd\\git.exe"

COMANDO PLATFORMIO (PATH non globale, usare percorso completo):
  C:\Users\User\.platformio\penv\Scripts\platformio.exe <comando>
Oppure aggiungere al PATH utente:
  C:\Users\User\.platformio\penv\Scripts
e poi usare semplicemente `pio`.


-------------------------------------------------------------------------------
2. STATO MIGRAZIONE PER MODULO
-------------------------------------------------------------------------------

| Modulo    | MCU        | Board PlatformIO          | Platform                     | Compila |
|-----------|------------|---------------------------|------------------------------|---------|
| Display   | ESP32-S3   | esp32-s3-devkitc1-n16r8   | pioarduino 55.03.312-1       | SI      |
| Router    | RP2350     | rpipico2                  | maxgerhardt/raspberrypi      | SI      |
| Ctrl      | RP2040     | rpipico                   | maxgerhardt/raspberrypi      | SI      |
| Teensy    | Teensy 4.1 | teensy41                  | teensy                       | SI      |
| Power     | LGT8F328P  | (specifica)               | lgt8fx                       | SI      |
| SynthB    | RP2350     | rpipico2                  | maxgerhardt/raspberrypi      | SI      |
| SynthA_M  | RP2350     | rpipico2                  | maxgerhardt/raspberrypi      | SI      |
| SynthA_V  | RP2350     | rpipico2                  | maxgerhardt/raspberrypi      | NO      |
| SynthA_V2 | RP2350     | rpipico2                  | maxgerhardt/raspberrypi      | NO      |
| Mod       | (da def.)  | —                         | —                            | NO      |

Display funziona anche a runtime (caricato e testato).


-------------------------------------------------------------------------------
3. platformio.ini — TEMPLATE PER TIPO DI MODULO
-------------------------------------------------------------------------------

### 3.1 DISPLAY (ESP32-S3, l'unico caso speciale)

[env:display]
platform = https://github.com/pioarduino/platform-espressif32/releases/download/55.03.312-1/platform-espressif32.zip
board = esp32-s3-devkitc1-n16r8
framework = arduino
monitor_speed = 115200

board_build.partitions = partitions.csv

build_src_filter =
    +<*>
    -<images/>

build_flags =
    -DLV_CONF_INCLUDE_SIMPLE
    -I$PROJECT_INCLUDE_DIR
    -std=gnu++17

build_unflags =
    -std=gnu++11
    -std=gnu++14

build_src_flags =
    -fpermissive

lib_deps =
    lvgl/lvgl@^8.4.0
    https://github.com/esp-arduino-libs/esp-lib-utils.git
    https://github.com/esp-arduino-libs/ESP32_IO_Expander.git
    https://github.com/esp-arduino-libs/ESP32_Display_Panel.git

Note Display:
- build_src_filter esclude src/images/ (gia inclusi in images.c)
- -std=gnu++17 obbligatorio per ESP32_Display_Panel
- build_unflags necessario perche il framework impone C++11/14
- -I$PROJECT_INCLUDE_DIR necessario per far vedere lv_conf.h a LVGL
- partitions.csv in root progetto (nvs, otadata, app0 15MB, spiffs, coredump)

### 3.2 RP2350 (Router, SynthA_*, SynthB, Mod)

[env:nome_modulo]
platform = https://github.com/maxgerhardt/platform-raspberrypi.git
board = rpipico2
framework = arduino
monitor_speed = 115200

build_flags =
    -std=gnu++17

lib_deps =
    ; specifiche del modulo (es. MIDI, Adafruit, ecc.)

Per SerialPIO (usato da Router) e NECESSARIO il core Philhower
fornito da maxgerhardt, NON la platform raspberrypi ufficiale.

### 3.3 RP2040 (Ctrl)

Come RP2350, ma board = rpipico.

Per Ctrl servono:
lib_deps =
    adafruit/Adafruit ADS1X15@^2.4.0

### 3.4 Teensy 4.1

[env:teensy41]
platform = teensy
board = teensy41
framework = arduino
monitor_speed = 115200

build_flags =
    -std=gnu++17

lib_deps =
    https://github.com/PaulStoffregen/SerialFlash.git

Audio.h, SPI.h, SD.h, EEPROM.h sono gia nel core Teensyduino.
SerialFlash va presa da GitHub (non e nel registro PlatformIO con
`paulstoffregen/SerialFlash`, nome non valido).

### 3.5 Power (LGT8F328P)

[env:power]
platform = lgt8f
board = (board specifica LGT8F328P)
framework = arduino
monitor_speed = 115200


-------------------------------------------------------------------------------
4. PATCH MANUALI ALLA LIBRERIA ESP32_Display_Panel
-------------------------------------------------------------------------------
ATTENZIONE: le patch vanno riapplicate se si fa `pkg install --force`
   o si cancella `.pio/libdeps/`.

Le patch correggono un bug con GCC 8.4 (Xtensa) relativo al pattern
`friend class Host` in classi CRTP. Causa: "specialization of
'Host<...>' after instantiation" e "must appear at namespace scope".

FILE DA PATCHARE:
- .pio/libdeps/display/ESP32_Display_Panel/src/drivers/host/esp_panel_host_i2c.hpp
- .pio/libdeps/display/ESP32_Display_Panel/src/drivers/host/esp_panel_host_spi.hpp
- (eventualmente qspi e rgb se il compilatore si ferma su di loro)

PATCH: rimuovere la friend class Host<...>; e rendere public il
costruttore e calibrateConfig(). Esempio per I2C:

class HostI2C : public Host<HostI2C, i2c_config_t, static_cast<int>(I2C_NUM_MAX)> {
public:
    template <typename U>
    friend struct esp_utils::GeneralMemoryAllocator;

    ~HostI2C() override;
    bool begin() override;

    // Resi public per compatibilita GCC 8.4
    HostI2C(int id, const i2c_config_t &config):
        Host<HostI2C, i2c_config_t, static_cast<int>(I2C_NUM_MAX)>(id, config) {}

    bool calibrateConfig(const i2c_config_t &config) override;
};

BACKUP CONSIGLIATO: salvare i file patchati in
Lud-WS-Display/_pio_patch_backup/ per ripristinarli dopo un update.

Alternativa futura: tornare a ESP32_Display_Panel v1.0.4 (non ha il bug).


-------------------------------------------------------------------------------
5. CONFIGURAZIONE BOARD SPECIFICA DISPLAY
-------------------------------------------------------------------------------

### 5.1 File include/ del Display

Devono esistere:
- include/lv_conf.h — copiato dal vecchio progetto Arduino
- include/esp_panel_board_supported_conf.h — con:
  #define ESP_PANEL_BOARD_DEFAULT_USE_SUPPORTED  (1)
  #if ESP_PANEL_BOARD_DEFAULT_USE_SUPPORTED
  #define BOARD_VIEWE_UEDX80480050E_WB_A    // WB_A funziona anche per WB_B
  #endif

### 5.2 Flag di compilazione necessari per lv_conf.h

- -DLV_CONF_INCLUDE_SIMPLE
- -I$PROJECT_INCLUDE_DIR

Senza il secondo, LVGL (libreria esterna) non trova lv_conf.h
(il path di default include/ viene aggiunto solo per i sorgenti del
progetto, non per le librerie di terze parti).


-------------------------------------------------------------------------------
6. STRUTTURA FILE OGNI MODULO (dopo migrazione)
-------------------------------------------------------------------------------
Modulo/
├── platformio.ini
├── partitions.csv        (solo Display)
├── src/
│   ├── main.cpp          (ex Modulo.ino)
│   ├── *.h               (tutti gli header del modulo)
│   └── *.cpp             (tutti i .cpp del modulo)
├── include/              (lv_conf.h, esp_panel_board_*.h — solo Display)
├── lib/                  (eventuali librerie locali)
├── .gitignore
└── README.md, VERSION, ecc.

REGOLE:
- Include tra file dentro src/ sono PIATTI (no ../, no src/)
- #include <Arduino.h> come PRIMA riga di main.cpp
- Forward declaration per funzioni usate prima della loro definizione
  (Arduino IDE le generava automaticamente, PlatformIO no)


-------------------------------------------------------------------------------
7. PROBLEMI RISOLTI E LORO FIX (per riferimento futuro)
-------------------------------------------------------------------------------

| Errore                                          | Causa                                  | Fix                                             |
|-------------------------------------------------|----------------------------------------|-------------------------------------------------|
| 'HIGH' was not declared in this scope           | Manca #include <Arduino.h>             | Aggiungere come prima riga di main.cpp          |
| 'func' was not declared in this scope           | Funzione usata prima della definizione | Forward declaration void func(); prima          |
| duplicate case value                            | Due #define K_* con stesso carattere   | Separare lo switch in uint8 + int32/uint16      |
| redefinition of X                               | Variabile definita due volte           | Cancellare duplicato; usare inline/extern       |
| specialization after instantiation              | Bug GCC 8.4 in ESP32_Display_Panel     | Patchare friend class Host -> public            |
| lv_conf.h: No such file or directory            | -I$PROJECT_INCLUDE_DIR mancante        | Aggiungere ai build_flags                       |
| SPI.h: No such file (Ctrl)                      | lib_deps include ADS1X15 ma non serve  | Rimuovere lib_deps non necessaria               |
| FileNotFoundError too long (Windows)            | Path > 260 caratteri                   | LongPathsEnabled + .platformio su D:            |
| Duplicate g_pongCount                           | Riga duplicata al paste                | Cancellare una                                  |
| 'g_notesSent' was not declared                  | Contatore dopo la funzione che lo usa  | Spostare i contatori PRIMA delle funzioni       |
| case label not within switch / crosses init     | Graffa { dopo case X: non chiusa       | Aggiungere } dopo il break;                     |


-------------------------------------------------------------------------------
8. dumpStatus() — SISTEMA DI DEBUG REMOTO
-------------------------------------------------------------------------------
Ogni modulo ha una funzione dumpStatus() che stampa su seriale USB
un dump strutturato dello stato interno. Formato [DUMP] key=value,
pensato per essere incollato in chat a Copilot/Claude per il debug.

### Moduli con dumpStatus() implementato

| Modulo   | Trigger locale   | Trigger remoto                                        |
|----------|------------------|--------------------------------------------------------|
| Teensy   | ? (gia esistente)| via LWS key '?'                                        |
| Display  | ? in loop()      | (opzionale)                                            |
| Router   | ? in loop()      | CMD_PARAM key '?' in handleDisplayFrameLws             |
| SynthA_M | ? in loop()      | CMD_PARAM key '?' in dispatchLocal                     |
| SynthB   | ? in loop()      | CMD_PARAM key '?' in on_param                          |
| Ctrl     | ? in loop()      | legacy T?&! in processRxCommand                        |

### Moduli da fare
- Mod
- Power
- SynthA_V
- SynthA_V2

### Come usarlo
1. Aprire il monitor seriale del modulo (115200 baud)
2. Digitare ? + Invio
3. Copiare l'output [DUMP] ... e incollarlo in chat

Per attivare dal Display (futuro): aggiungere un bottone
"DUMP [modulo]" che invii send_param_update(ID_<modulo>, '?', 0).


-------------------------------------------------------------------------------
9. WORKSPACE MULTI-ROOT VS CODE
-------------------------------------------------------------------------------
File: Lud-WS.code-workspace nella root del repo.
ATTENZIONE: prima si chiamava .code-workspace (senza nome), rinominato.
Senza nome, @workspace di Copilot non funzionava correttamente.

Contenuto (per riferimento):
{
  "folders": [
    { "name": "Display", "path": "Lud-WS-Display" },
    { "name": "Router", "path": "Lud-WS-Router" },
    ...
  ]
}

### Estensioni consigliate (extensions.json in ogni modulo)

{
  "recommendations": [
    "Jason2866.esp-decoder",
    "platformio.platformio-ide"
  ],
  "unwantedRecommendations": [
    "ms-vscode.cpptools-extension-pack",
    "pioarduino.pioarduino-ide"
  ]
}

ATTENZIONE: NON installare pioarduino.pioarduino-ide, entra in
conflitto con platformio.platformio-ide. Si usa la platform
pioarduino (per il Display) ma l'estensione PlatformIO classica.

### Multi-root vs finestre singole
- Navigazione + Copilot @workspace: usare il workspace multi-root
- Build/upload: aprire la cartella singola del modulo in finestra
  dedicata (PlatformIO gestisce un progetto attivo per finestra)

Si possono tenere aperte piu finestre VS Code in parallelo su moduli
diversi. Non fare build simultanee sullo stesso progetto.


-------------------------------------------------------------------------------
10. GIT E .gitignore
-------------------------------------------------------------------------------

### Regola fondamentale
.pio/ NON va su Git (build, libdeps, cache — centinaia di MB).
Va in .gitignore di ogni modulo.

### .gitignore corretto per modulo

# PLATFORMIO
.pio/
.pioenvs/
.piolibdeps/

# BUILD
*.elf
*.hex
*.bin
*.map

# BACKUP
*.bak
*.old
*.tmp
*~

# SYSTEM
.DS_Store
Thumbs.db
*.swp
*.swo
*.swn

# IDE
.idea/
.vscode/c_cpp_properties.json
.vscode/launch.json
.vscode/browse.vc.db*
.vscode/ipch/
*.code-workspace

# SD CARD DATA
/data/
/sd/

### Attenzione su *.csv e *.txt
NON escluderli globalmente: partitions.csv (Display) e i file
nomi_preset*.txt, kit_names.txt devono essere versionati.

### Se .pio e gia stato committato
git rm -r --cached */\.pio
git commit -m "Rimuovi .pio dal tracking"

### Workspace da versionare
Aggiungere al .gitignore della root:
*.code-workspace
!Lud-WS.code-workspace
Il workspace ufficiale va su Git, quelli personali no.


-------------------------------------------------------------------------------
11. SCRIPT DI PULIZIA (pio-clean.bat)
-------------------------------------------------------------------------------
Nella cartella di ogni modulo si puo creare pio-clean.bat con menu:
[1] Veloce      -> cancella .pio/build
[2] Media       -> + idedata.json
[3] Globale     -> .platformio/.cache (D:\platformio\.cache)
[4] Completa    -> + libdeps (ATTENZIONE: perde le patch!)
[5] Info        -> mostra dimensioni
[0] Esci

Fa backup automatico delle patch in _pio_patch_backup/ prima di [4].
Script completo disponibile nel messaggio precedente della sessione.


-------------------------------------------------------------------------------
12. STATO FLASH/RAM DISPLAY (ultima build)
-------------------------------------------------------------------------------
RAM:   24.4% (80.100 byte su 327.680)
Flash:  7.2% (1.126.863 byte su 15.728.640)
Binario: 1.12 MB (in Arduino IDE era ~1.5-2 MB perche le librerie
         venivano linkate staticamente)


-------------------------------------------------------------------------------
13. MODULI DA MIGRARE (per la prossima sessione)
-------------------------------------------------------------------------------

### 13.1 SynthA_V e SynthA_V2 (priorita alta)
Sono IDENTICI a SynthA_M come struttura. Differenze:
- SynthA_V:  #define MCU_ID 'b' -> NUM_VOCI=2, VOCE_BASE=1
- SynthA_V2: #define MCU_ID 'c' -> NUM_VOCI=2, VOCE_BASE=3
I file synthConfig.h, synthLws.h, synthEngine.h, ecc. sono
condivisi (probabilmente copie o submodule).

PROCEDURA:
1. Copiare platformio.ini di SynthA_M
2. Copiare/adattare src/
3. Aggiungere #include <Arduino.h> come prima riga di main.cpp
4. Verificare MCU_ID corretto
5. Applicare i fix gia fatti per SynthA_M:
   - Forward declaration voiceToLocal in synthLws.h
   - static int calibraNota = -1; in synthLws.h
   - Switch diviso in uint8 + int32/uint16 in synthA_presetEntry
   - void dumpStatus(); forward declaration
   - Rimuovere lws_set_synth_callbacks (non esiste, non serve)
6. Compilare
7. Scrivere dumpStatus() (copiare da SynthA_M)

### 13.2 Mod (priorita media)
Modulo vuoto. Da definire:
- MCU (probabilmente RP2350)
- Ruolo (riceve CHORUS/PHASER/DLY dal Display)
- Struttura file

### 13.3 dumpStatus() per Power (priorita bassa)
Simile al Ctrl (protocollo legacy). LGT8F328P ha poca RAM/flash,
loggare solo l'essenziale.

### 13.4 Test hardware end-to-end
Caricare tutti i moduli e verificare:
- Discovery MCU dal Display
- Trasferimento preset (Display -> SynthA_M -> b -> c)
- MIDI hardware dal Router
- Drum pattern (Display <-> Teensy)
- Effetti CHORUS/PHASER/DLY (Display -> Mod)


-------------------------------------------------------------------------------
14. COMANDI UTILI
-------------------------------------------------------------------------------

### PlatformIO (da cartella modulo)
# Build
C:\Users\User\.platformio\penv\Scripts\platformio.exe run

# Upload
C:\Users\User\.platformio\penv\Scripts\platformio.exe run -t upload
C:\Users\User\.platformio\penv\Scripts\platformio.exe run -t upload --upload-port COM5

# Monitor seriale
C:\Users\User\.platformio\penv\Scripts\platformio.exe device monitor

# Clean build (per fix dopo cambio platformio.ini)
C:\Users\User\.platformio\penv\Scripts\platformio.exe run -t clean

# Reinstall dependencies (dopo cambio lib_deps)
C:\Users\User\.platformio\penv\Scripts\platformio.exe pkg install --force

# Elenca board disponibili
C:\Users\User\.platformio\penv\Scripts\platformio.exe boards rpipico
C:\Users\User\.platformio\penv\Scripts\platformio.exe boards esp32-s3

### PowerShell — ricerca nel progetto
# Trova dove e definita una funzione
Select-String -Path src\*.h,src\*.cpp -Pattern "void nomefunzione" | Select-Object Path, LineNumber, Line

# Cerca tutte le occorrenze di una variabile
Get-ChildItem -Recurse -Include *.h,*.cpp,*.ino | Select-String -Pattern "nomevariabile" | Select-Object Path, LineNumber, Line

# Trova file con estensione specifica
Get-ChildItem -Recurse -Filter extensions.json | Select-Object FullName


-------------------------------------------------------------------------------
15. NOTE SU DEBUG HARDWARE
-------------------------------------------------------------------------------
Il debug hardware (breakpoint) e stato valutato e SCARTATO per ora:
- Display (ESP32-S3): possibile con debugger JTAG integrato (nessun
  hardware aggiuntivo), ma non necessario per ora
- Router/Ctrl/Synth (RP2350/RP2040): richiede Raspberry Pi Debug Probe
- Teensy 4.1: solo con libreria TeensyDebug (GDB stub software)
- Power (LGT8F328P): molto complesso, meglio Serial.print

Strategia adottata: printf + dumpStatus() + Copilot coprono il 90%
dei casi. Il debug hardware si valutera solo se emergono bug "duri"
(memory corruption, crash inspiegabili dentro LVGL, ecc.).

Se in futuro serve, procedura per ESP32-S3:
1. Aggiungere a platformio.ini:
   debug_tool = esp-builtin
   debug_init_break = tbreak setup
   build_type = debug
2. Su Windows, con Zadig, reinstallare il driver dell'Interfaccia 2
   dell'ESP32-S3 come WinUSB o libusbK
3. Collegare il Display via porta USB nativa (etichettata "USB", non
   "Serial"/CH340)
4. Premere F5 in VS Code


-------------------------------------------------------------------------------
16. PROSSIMO STEP CONSIGLIATO
-------------------------------------------------------------------------------
A) Migrare SynthA_V e SynthA_V2 (identici a SynthA_M, 15 min ciascuno)
B) Definire struttura Mod e migrarlo
C) Aggiungere dumpStatus() a Power
D) Test hardware end-to-end con tutti i moduli migrati
E) Documentare lo stato attuale in un commit Git "PlatformIO migration
   complete 7/10 modules"


================================================================================
FINE RIEPILOGO
================================================================================
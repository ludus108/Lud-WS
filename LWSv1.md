# LWSv1 - LUD-WS Serial Protocol

**Versione:** 1.1 | **Stato:** stabile | **Hardware:** ESP32-S3 (Display), RP2350 (Router), vari (nodi)

Protocollo seriale **proprietario** del progetto LUD-WS. Non e' uno standard
pubblico. Condiviso da tutti i firmware tramite `serial_protocol.h`. Il
Display (master) parla LWS solo col Router, che fa da bridge verso i nodi
(protocollo legacy con terminatori `&!`).

[Display] --UART 115200 8N1--> [Router] --SerialPIO--> [Synth A1/A2/A3]
--SerialPIO--> [Synth B]
--SerialPIO--> [Ctrl / Mod]
--SerialPIO--> [Teensy / Power]

---

## 1. Livello fisico

- UART hardware, **115200 8N1**, no flow control
- Display: RX=18, TX=17
- Router: Serial2 verso Display; SerialPIO 2/3, 4/5, 6/7, 10/11, 12/13, 14/15 verso i nodi

---

## 2. Formato frame (LWSv1.1)
+--------+-----+-----+-----+-------------+------+----+----+
| SENDER | SEQ | CMD | LEN | PAYLOAD | CRC8 | & | ! |
| 1 B | 1 B | 1 B | 1 B | 0..255 B | 1 B |0x26|0x21|
+--------+-----+-----+-----+-------------+------+----+----+


- **SENDER**: ID mittente (char ASCII)
- **SEQ**: sequence number per sender (0..255, wrap)
- **CMD**: codice comando
- **LEN**: lunghezza payload
- **CRC8**: CRC-8/ATM (poly 0x07, init 0x00) su SENDER..PAYLOAD
- **`&!`**: terminatori fissi

**Vincoli:** i byte `0x26` e `0x21` non devono comparire nel payload.
**Overhead minimo:** 6 byte. **CRC errato:** frame scartato silenziosamente.

**Parser** (`LwsParser`, `serial_protocol.h`): FSM a 8 stati
`ST_SENDER -> ST_SEQ -> ST_CMD -> ST_LEN -> [ST_PAYLOAD] -> ST_CRC -> ST_END1 -> ST_END2`.
Auto-risincronizzante: se un terminatore non corrisponde, torna a `ST_SENDER`.
`feed()` ritorna `true` solo a frame completo e CRC valido.

---

## 3. Identificatori

| ID  | Costante       | Nome     | Discovery |
|:---:|----------------|----------|:---------:|
| 'D' | ID_DISPLAY     | Display  | NO (master) |
| 'a' | ID_SYNTH_A1    | Synth A1 | SI        |
| 'b' | ID_SYNTH_A2    | Synth A2 | SI        |
| 'c' | ID_SYNTH_A3    | Synth A3 | SI        |
| 'B' | ID_SYNTH_B     | Synth B  | SI        |
| 'R' | ID_ROUTER      | Router   | SI        |
| 'C' | ID_CTRL        | Ctrl     | SI        |
| 'M' | ID_MOD         | Mod      | SI        |
| 'T' | ID_TEENSY      | Teensy   | SI        |
| 'P' | ID_POWER       | Power    | SI        |

`MAX_MCU = 10`, `DISC_TARGET_COUNT = 9`.

---

## 4. Comandi

| CMD | Costante        | Direzione       | Payload                          |
|:---:|-----------------|-----------------|----------------------------------|
| 'p' | CMD_PING        | Display -> Nodo | [target_id]                      |
| 'P' | CMD_PONG        | Nodo -> Display | vuoto                            |
| 'S' | CMD_PARAM       | bidir           | [target, key, value]             |
| 'R' | CMD_PARAM_REL   | bidir           | [target, key, value]             |
| 'A' | CMD_PARAM_ACK   | bidir           | [acked_seq, acked_cmd]           |
| 'G' | CMD_GET_PARAM   | riservato       | -                                |
| 'E' | CMD_ERROR       | Nodo -> Display | [target, msg...] (max 1+63 B)    |
| 'Z' | CMD_STATUS      | riservato       | -                                |

**PING**: broadcast fisico, risponde solo il nodo con ID = payload[0].
**PONG**: vuoto, identita' in SENDER.
**PARAM**: fire-and-forget, nessun ACK. Per slider/pot ad alta frequenza.
**PARAM_REL**: reliable, richiede ACK. Per preset/config/cambi critici.
**PARAM_ACK**: conferma `[seq_ricevuto, cmd_ricevuto]`.
**ERROR**: messaggio rosso nel log + nodo marcato offline.

---

## 5. Mapping parametri

Il payload di PARAM/PARAM_REL usa una **lettera** come chiave verso un
indice in `timbrA[]` / `timbrB[]`. **Le due tabelle non sono allineate**:
la stessa lettera puo' mappare a indici diversi. Il campo `synth_target`
('A' o 'B') seleziona la tabella.

**mapA** (23 voci):
`a`=wave_mode_A, `b`=wave_A, `c`=shape_A, `d`=shape_lev_A, `e`=shape_rate_A,
`f`=lfo_pitch_lev_A, `g`=cutOff_A, `h`=res_A, `i`=vcf_lfo_A, `l`=vcf_env_A,
`m`=vcf_ana_env_A, `n`=ana_ATTACK_A, `o`=ana_DECAY_A, `p`=ana_SUSTAIN_A,
`q`=ana_RELEASE_A, `r`=vir_ATTACK_A, `s`=vir_DECAY_A, `t`=vir_SUSTAIN_A,
`u`=vir_RELEASE_A, `v`=lfo_wave_A, `z`=lfo_rate_A, `x`=vca_vir_env_A,
`y`=vca_lfo_A

**mapB** (26 voci):
`a`=wave_mode_B, `b`=wave_B, `c`=shape_B, `d`=shape_lev_B, `e`=shape_rate_B,
`f`=lfo_pitch_lev_B, `g`=vcf_mode_B, `h`=cutOff_1_B, `i`=cutOff_2_B,
`l`=cutOff_3_B, `m`=res_B, `n`=vcf_lfo_B, `o`=vcf_env_B, `p`=vcf_Bna_env_B,
`q`=ana_BTTACK_B, `r`=ana_DECAY_B, `s`=ana_SUSTAIN_B, `t`=ana_RELEASE_B,
`u`=vir_BTTACK_B, `v`=vir_DECAY_B, `w`=lfo_rate_B, `x`=vir_RELEASE_B,
`y`=lfo_wave_B, `z`=vir_SUSTAIN_B, `j`=vca_lfo_B, `k`=vca_vir_env_B

---

## 6. Discovery

State machine non bloccante sul Display, pilotata da `discover_all_mcu_poll()`
ad ogni `loop()`.

start() --> DISC_START --300ms--> DISC_PING_SEND --9 ping--> DISC_WAIT
|
(tutti PONG | timeout 2000ms) |
v
DISC_DONE
|
restart() <---------+


- 1 ping per ciclo di `poll()`, cicla su `DISC_TARGETS[]`
- Early exit se tutti i 9 nodi rispondono
- Timeout globale: 2000 ms
- Restart rifiutato se discovery gia' in corso

---

## 7. ACK (reliable)

Coda pending lato mittente: 8 slot, ognuno con `{seq, cmd, len, data[8],
retries, t_sent}`.

Mittente Ricevente
| PARAM_REL seq=N |
|--------------------------------->|
| pending_alloc() | applica param
| |
| PARAM_ACK [N, 'R'] |
|<---------------------------------|
| pending_find(N) -> chiude |
| |
| (timeout 300ms -> retry, max 3) |


- **PENDING_MAX** = 8
- **ACK_TIMEOUT_MS** = 300
- **ACK_RETRIES_MAX** = 3 (tempo totale ~1.2 s)
- Coda piena: invia comunque ma senza tracking, log "Coda ACK piena"
- Match richiede `seq` E `cmd` corrispondenti; ACK orfani ignorati

---

## 8. Traffico

| Frame                | TX | RX | Tot |
|----------------------|:--:|:--:|:---:|
| PING                 | 10 | 9  | 19  |
| PONG                 | 9  | 0  | 9   |
| PARAM (fire-forget)  | 10 | 0  | 10  |
| PARAM_REL + ACK      | 10 | 9  | 19  |
| ERROR (msg 10 char)  | 18 | 0  | 18  |

Rispetto a LWSv1 (senza CRC/SEQ): slider +25%, comandi critici +137%.

**Linee guida:** PARAM a ~30 Hz max per slider; PARAM_REL per preset/config;
PING heartbeat >= 1 s. Throttling lato mittente con `millis()`.

---

## 9. Changelog

**v1.1** (attuale)
- [10.1] FIX: `ID_POWER` aggiunto a `MCU_IDS[]`/`MCU_NAMES[]`, `MAX_MCU=10`
- [10.2] ADD: CRC-8/ATM su SENDER..PAYLOAD
- [10.3] ADD: campo SEQ + `CMD_PARAM_REL` ('R') + `CMD_PARAM_ACK` ('A')
- [10.3] ADD: coda pending 8 slot, retry 3x/300ms
- [10.3] CHANGE: `CMD_PARAM` ('S') ora fire-and-forget
- CHANGE: rimosso `lws_parse_byte()` globale; usare `LwsParser::feed()`
- CHANGE: `lws_send_frame()` ha parametro `seq` extra

**v1** (baseline)
- Frame: `[SENDER][CMD][LEN][PAYLOAD][&!]`
- Comandi: `p P S G A E Z`
- Nessun CRC, nessun SEQ, nessun retry

---

## 10. Known issues

1. **Dual-mode Router**: il parser LWS consuma tutti i byte, il legacy non
   vede nulla. Soluzione pulita: due UART separate o handshake iniziale.
2. **Collisioni bus**: 9 PING in rapida sequenza possono sovrapporre i PONG.
   Mitigato dal ping sequenziale uno-alla-volta.
3. **Param verso nodi**: forwarding nel Router non ancora implementato.
   TODO: definire formato legacy e aggiungere `forwardParamToNodeLegacy()`.
4. **No sequence tracking PONG**: duplicati ignorati perche' nodo gia'
   online. Per distinguere "tornato online" aggiungere timestamp last-seen.
5. **CMD_ERROR Display->Nodo**: definito ma mai inviato.

---

## 11. Riferimenti

| File                    | Ruolo                                  |
|-------------------------|----------------------------------------|
| `serial_protocol.h`     | Frame + parser + CRC (condiviso)       |
| `comunicazioni.h` (Dis) | API LWS lato Display                   |
| `comunicazioni.h` (MCU) | API LWS lato MCU con callbacks         |
| `Lud-WF-Display.ino`    | Master, chiama `leggiSer()`+`com_poll()` |
| `Lud-WS-Router.ino`     | Bridge Display <-> nodi legacy         |

---

## 12. Note

Protocollo proprietario LUD-WS, non standard pubblico. Tutti i firmware
devono usare la **stessa versione** di `serial_protocol.h`. Cambio di
versione maggiore (v1 -> v2) richiede deploy atomico di tutti i nodi.
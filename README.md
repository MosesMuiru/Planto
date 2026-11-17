# Planto

Smart planting system built on a **Raspberry Pi 5** running **[Nerves](https://nerves-project.org/)** (Elixir).
It monitors soil moisture, waters the plant with a small pump, and streams/snaps images from a Pi camera.

## Hardware

KiCad 9 project: [`planto/plant/`](planto/plant/) — a Pi 5 HAT that sits on the 40-pin header.

| Block | Parts | Pi 5 pin |
|---|---|---|
| Moisture ADC | ADS1115 (U1), I²C addr `0x48`, AIN0 = sensor AO | GPIO2 SDA (pin 3), GPIO3 SCL (pin 5) |
| Sensor power switch | AO3401A P-FET (Q1), 100k pull-up keeps it off at boot | GPIO17 (pin 11) — **LOW = sensor on** |
| Sensor digital out | LM393 DO via 1k | GPIO27 (pin 13) |
| Pump driver | AO3400A N-FET (Q2), SS14 flyback, 47 µF, screw terminal J3 | GPIO22 (pin 15) — HIGH = pump on |
| Status LED | Green LED + 330 Ω | GPIO23 (pin 16) — HIGH = on |
| ADC alert/ready | ADS1115 ALERT/RDY, 10k pull-up | GPIO24 (pin 18) |

- **Soil sensor** (J2, 4-pin 2.54 mm): `1 VCC  2 GND  3 DO  4 AO` — FC-28 / YL-69 resistive probe with LM393 board, run at 3.3 V.
  Power it only while reading (GPIO17 low for ~10–50 ms) to slow probe corrosion.
- **Pump**: 5 V from the Pi's 5 V rail (keep it under ~1 A).
- **Camera**: Pi camera on the Pi 5's own CSI/MIPI connector (not on the HAT).

## Firmware (Nerves)

Target: `rpi5`. Suggested Elixir libraries:

- [`circuits_i2c`](https://hex.pm/packages/circuits_i2c) — ADS1115 on bus `"i2c-1"`, address `0x48`
  (or [`ads1115`](https://hex.pm/packages/ads1115))
- [`circuits_gpio`](https://hex.pm/packages/circuits_gpio) — sensor power, DO, pump, LED, ALERT
- Camera via `rpicam-still` / `rpicam-vid` (libcamera) on the Nerves system

Reading cycle: GPIO17 → 0, wait ~20 ms, read ADS1115 AIN0, GPIO17 → 1. Lower AO voltage = wetter soil.

## Status

- [x] Schematic (ERC clean)
- [ ] PCB layout (65 × 56.5 mm HAT outline)
- [ ] Nerves firmware

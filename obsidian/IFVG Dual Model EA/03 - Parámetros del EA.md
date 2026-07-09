---
tags: [trading, mt5, ea, parametros]
---

# Parámetros del EA (inputs)

## General

| Input | Default | Descripción |
|---|---|---|
| `InpMagic` | `20260708` | Magic number (uno distinto por cuenta/instancia) |
| `InpModelMode` | `MODE_BOTH` | `MODE_MODEL1` / `MODE_MODEL2` / `MODE_BOTH` |
| `InpMaxSpreadPoints` | `3000` | Spread máximo |
| `InpMaxOpenPositions` | `10` | Máx. posiciones abiertas del EA |

## Modelo 1 (M15 → M5 → IFVG)

| Input | Default | Descripción |
|---|---|---|
| `InpM1BiasTF` | `M15` | TF de bias |
| `InpM1EntryTF` | `M5` | TF de entrada |
| `InpM1SwingBars` | `3` | Barras a cada lado del swing (fractal) |
| `InpM1BiasLookback` | `40` | Barras M15 para buscar estructura |
| `InpM1FvgMinPoints` | `10` | Tamaño mínimo del FVG |
| `InpM1ZoneExpiryBars` | `120` | Expiración de zona IFVG (barras M5) |

## Modelo 2 (sweep → displacement → IFVG)

| Input | Default | Descripción |
|---|---|---|
| `InpM2TF` | `M1` | TF del modelo |
| `InpM2SweepLookback` | `30` | Barras para detectar sweep |
| `InpM2SweepWindow` | `15` | Barras tras el sweep para displacement+IFVG |
| `InpM2DispFactor` | `1.8` | Cuerpo displacement ≥ factor × cuerpo medio |
| `InpM2AvgBodyBars` | `20` | Barras para cuerpo medio |
| `InpM2FvgMinPoints` | `5` | Tamaño mínimo del FVG |
| `InpM2MinRangePoints` | `175` | Rango mínimo reciente (baseline) |
| `InpM2RangeBars` | `15` | Barras para medir el rango |
| `InpM2ZoneExpiryBars` | `90` | Expiración de zona IFVG (barras M1) |

## Gestión y salida

| Input | Default | Descripción |
|---|---|---|
| `InpInitialBalance` | `400.0` | Balance inicial de referencia (¡ajustar por cuenta!) |
| `InpBaseLot` | `0.03` | Lote base |
| `InpLotStepPer1000` | `0.10` | Lotes extra por cada $1000 de beneficio |
| `InpMaxLot` | `5.0` | Lote máximo |
| `InpStopPoints` | `150` | SL fijo (puntos) |
| `InpMaxOpenLosing` | `3` | Bloqueo por posiciones en negativo |
| `InpMaxOpenRiskPct` | `50.0` | Riesgo abierto máx. (% balance) |
| `InpExitMode` | `EXIT_TRAILING` | `EXIT_TRAILING` o `EXIT_FIXED_RR` |
| `InpTrailStartPoints` | `75` | Trailing start |
| `InpTrailDistPoints` | `50` | Trailing distance |
| `InpFixedRR` | `2.5` | RR si TP fijo |

## Killzones (opcional)

| Input | Default | Descripción |
|---|---|---|
| `InpUseKillzones` | `false` | Activar filtro horario |
| `InpKZ1Start` / `InpKZ1End` | `08:00` / `11:00` | Killzone 1 (hora servidor) |
| `InpKZ2Start` / `InpKZ2End` | `13:30` / `16:00` | Killzone 2 (hora servidor) |

Contexto de los valores en [[02 - Gestión de riesgo]].

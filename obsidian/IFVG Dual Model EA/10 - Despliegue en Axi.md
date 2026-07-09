---
tags: [trading, axi, live, despliegue]
creado: 2026-07-09
---

# Despliegue en Axi (cuenta real)

## Especificación BTCUSD en Axi (verificada 2026-07-09)

- **Dígitos: 2** → 1 punto MT5 = **$0.01** (los backtests usaban puntos de $1)
- 1 CFD = 1 Bitcoin · Volumen mín 0.01, paso 0.01, máx 20
- Margen inicial 0.5% (~€272/lote) → 0.03 lotes ≈ **€8.16** ✅ sin problema de margen
- Nivel de stops: 5 puntos ($0.05) — irrelevante
- Sesiones: casi 24/7 (sábado abre 01:00)
- **Swap largos −20% anual, triple el viernes** — solo afecta si una posición pasa la noche

## Conversión de parámetros (×100)

| Input | Baseline ($1/punto) | **Axi (punto=$0.01)** |
|---|---:|---:|
| `InpStopPoints` | 150 | **15000** |
| `InpTrailStartPoints` | 75 | **7500** |
| `InpTrailDistPoints` | 50 | **5000** |
| `InpM2MinRangePoints` | 175 / 125 (agresivo) | **17500 / 12500** |
| `InpM1FvgMinPoints` | 10 | **1000** |
| `InpM2FvgMinPoints` | 5 | **500** |
| `InpMaxSpreadPoints` | 3000 | **3000** (= $30, ya estaba en unidades de $0.01) |

Presets listos en el repo:
- `mt5/ifvg_dual_model_ea/presets/IFVG_DualModel_Axi_BTCUSD.set`
- `mt5/ifvg_dual_model_ea_aggressive/presets/IFVG_DualModel_Aggressive_Axi_BTCUSD.set`

## Checklist de arranque

1. MT5 de Axi en el VPS, login con la cuenta live.
2. Copiar `.mq5` a `MQL5/Experts/`, compilar (F7).
3. Arrastrar el EA a BTCUSD → pestaña *Parámetros* → **Cargar** → elegir el `.set`.
4. **Cambiar `InpInitialBalance` al balance real de la cuenta.**
5. Marcar "Permitir trading algorítmico" + botón **Algo Trading**.
6. Primeros días: vigilar panel del gráfico y pestaña *Expertos*; apuntar en [[06 - Registro de pruebas]].

> [!warning] Secuencia recomendada
> Demo de Axi 3–5 días (mismo feed y especificación) → live pequeña con la versión **normal** → la agresiva solo tras días limpios de la normal.

---
tags: [trading, mt5, instalacion]
---

# Instalación y uso

## Instalación

1. Copiar `IFVG_DualModel_EA.mq5` a `MQL5/Experts/` del terminal.
2. Compilar en MetaEditor (`F7`). Solo usa `Trade\Trade.mqh` estándar, sin librerías externas.
3. Arrastrar el EA al gráfico de `BTCUSD` (el TF del gráfico da igual: cada modelo usa sus propios TF internamente).
4. Activar **Algo Trading**.

## Checklist antes de live

- [x] Compilado sin errores
- [x] Probado — **funciona bien** (2026-07-08, ver [[06 - Registro de pruebas]])
- [ ] `InpInitialBalance` ajustado al balance real de la cuenta destino
- [ ] Magic number distinto si corre en más de un terminal/cuenta
- [ ] Verificar spread real del bróker en BTCUSD frente a `InpMaxSpreadPoints`
- [ ] Monitorizar los primeros días en el VPS (conexión, ejecución, trailing)

## Despliegue en las dos cuentas live (VPS)

- Cada VPS lleva su propio terminal MT5 con el EA compilado.
- Ajustar por cuenta: `InpInitialBalance` (balance real) y `InpMagic` (distinto en cada una).
- El panel del gráfico (`Comment`) muestra: modo, posiciones abiertas/en negativo, zonas armadas por modelo, sweep activo, lote actual y balance.

## Panel de estado

```
IFVG DualModel EA | Modo: MODE_BOTH
Posiciones: 2 (negativas: 1 / max 3)
Zonas armadas M1: 1 | M2: 0 | Sweep M2: 0
Lote actual: 0.03 | Balance: 412.50
```

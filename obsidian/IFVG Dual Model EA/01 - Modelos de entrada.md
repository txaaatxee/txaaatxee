---
tags: [trading, ifvg, ict, modelos]
---

# Modelos de entrada IFVG

Ambos modelos entran siempre por **retest**: el precio vuelve a la zona IFVG después de la vela de inversión. Una sola operación por zona.

## Definiciones base (ICT)

- **FVG** (3 velas): alcista si `low[1] > high[3]`; bajista si `high[1] < low[3]`.
- **IFVG** (inversión): un FVG alcista se invierte cuando una vela **cierra por debajo** de su borde inferior (pasa a zona bajista); un FVG bajista se invierte cuando una vela **cierra por encima** de su borde superior (pasa a zona alcista).
- **Sweep**: la vela supera el máximo/mínimo de las últimas N barras y **cierra de vuelta** dentro del rango.
- **Displacement**: cuerpo de vela ≥ 1.8× el cuerpo medio de las últimas 20 velas (configurable).

## Modelo 1 — M15 → M5 → IFVG

1. **Bias en M15** por MSS simple: alcista si el último cierre M15 rompe el último swing high (fractal de 3 barras); bajista si rompe el swing low; neutro = no opera.
2. **IFVG en M5** alineado con el bias:
   - Bias alcista → FVG bajista invertido = zona de soporte → **largo**.
   - Bias bajista → FVG alcista invertido = zona de resistencia → **corto**.
3. **Entrada** cuando el precio retestea la zona (máx. 120 barras M5 de vida).

## Modelo 2 — sweep → displacement → IFVG (M1)

1. **Filtro de rango**: rango de las últimas 15 barras ≥ 175 puntos (si no, se anula el sweep).
2. **Sweep** sobre las últimas 30 barras; ventana de validez: 15 barras.
3. **Displacement** en dirección contraria al sweep (cuerpo ≥ 1.8× media).
4. La vela de displacement **invierte un FVG previo** contrario → zona IFVG armada.
   - Sweep de mínimos → displacement alcista → FVG bajista invertido → **largo**.
   - Sweep de máximos → displacement bajista → FVG alcista invertido → **corto**.
5. **Entrada** en el retest de la zona (máx. 90 barras M1 de vida).

Ver parámetros exactos en [[03 - Parámetros del EA]] y decisiones de diseño en [[05 - Huecos y decisiones]].

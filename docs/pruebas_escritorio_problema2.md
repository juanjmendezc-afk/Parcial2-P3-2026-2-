# Problema 2: Escapar de la isla — prueba de escritorio de la búsqueda recursiva

Cubre el punto **"búsqueda de rutas mediante recursión"** del Problema 2: `Busqueda.rutas/3` y `Busqueda.explorar/6` en `problema2_isla/isla.exs`. La validación previa del mapa está en `pruebas_escritorio_validaciones.md`.

La prueba se construyó a partir de una traza real de la ejecución (rastreador `:dbg` de Erlang).

---

## 1. Caso pequeño y representativo

Archivo `problema2_isla/datos_prueba/isla_pequena.txt`:

```
          col 0  col 1  col 2  col 3  col 4
fila 0      ~      ~      ~      ~      ~
fila 1      ~      P      C      C      ~
fila 2      ~      D      T      C      ~
fila 3      ~      C      C      B      ~
fila 4      ~      ~      ~      ~      ~
```

Terrenos que intervienen (de `terrenos.csv`):

| Símbolo | Nombre | Transitable | Costo al entrar |
| --- | --- | --- | --- |
| `P` | inicio | sí | 0 (la posición inicial no suma) |
| `C` | camino | sí | 1 |
| `D` | terreno difícil | sí | 2 |
| `B` | bote | sí | 1 |
| `T` | árbol | no | — |
| `~` | agua | no | — |

Es representativo porque en 9 llamadas aparecen todas las decisiones de la búsqueda: entrar a una posición transitable, descartar agua y árboles por *pattern matching*, descartar posiciones ya visitadas y llegar al bote (caso base). Además produce dos rutas con **los mismos movimientos y distinto costo**, que es justo lo que el enunciado pide distinguir.

- Inicio: `{1,1}` · Bote: `{3,3}`
- Orden en que se prueban las direcciones (`@movimientos`): **abajo** `{1,0}`, **derecha** `{0,1}`, **arriba** `{-1,0}`, **izquierda** `{0,-1}`.

## 2. Cómo funciona `explorar/6`

```elixir
explorar(mapa, posicion_actual, bote, camino, visitadas, costo)
```

| Parámetro | Qué guarda |
| --- | --- |
| `mapa` | `%{ {fila, columna} => %Terreno{} }`, construido con `Mapa.construir/2` |
| `posicion_actual` | Dónde está la persona en esta llamada |
| `bote` | La posición del bote (no cambia) |
| `camino` | Las posiciones recorridas, **al revés** (la última va primero) |
| `visitadas` | `MapSet` con las posiciones de la ruta actual, para no repetirlas |
| `costo` | Costo acumulado hasta `posicion_actual` |

Cláusulas, en el orden en que Elixir las prueba:

1. **Caso base** `explorar(_mapa, bote, bote, ...)`: la variable `bote` aparece dos veces, así que solo coincide cuando la posición actual **es** el bote. Devuelve una lista con una ruta: `[%Ruta{posiciones: Enum.reverse(camino), costo: costo}]`.
2. **Caso recursivo**: para cada una de las 4 direcciones calcula `siguiente` y decide con `case Map.get(mapa, siguiente)`:
   - `nil` → fuera del mapa → `[]`
   - `%Terreno{transitable: false}` → agua o árbol → `[]` (*pattern matching* sobre el struct)
   - `%Terreno{costo: costo_terreno}` → transitable:
     - si `siguiente` ya está en `visitadas` → `[]`
     - si no → llamada recursiva con `[siguiente | camino]`, `MapSet.put(visitadas, siguiente)` y `costo + costo_terreno`

   `Enum.flat_map` junta en una sola lista las rutas que devuelven las 4 direcciones.

## 3. Prueba de escritorio

Abreviaturas: **T** = árbol, **~** = agua, **visitada** = ya está en `visitadas`.

### Llamada #1 · `explorar({1,1}, costo = 0)` · camino: {1,1}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {2,1} | `D` transitable, costo 2 | No visitada → **llamada #2** con costo 0 + 2 = **2** | [Ruta A] |
| derecha | {1,2} | `C` transitable, costo 1 | No visitada → **llamada #6** con costo 0 + 1 = **1** | [Ruta B] |
| arriba | {0,1} | `~` no transitable | Se descarta | [] |
| izquierda | {1,0} | `~` no transitable | Se descarta | [] |

`flat_map` → **[Ruta A, Ruta B]** (resultado final de la búsqueda)

### Llamada #2 · `explorar({2,1}, costo = 2)` · camino: {1,1} → {2,1}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {3,1} | `C` transitable, costo 1 | No visitada → **llamada #3** con costo 2 + 1 = **3** | [Ruta A] |
| derecha | {2,2} | `T` no transitable | Se descarta | [] |
| arriba | {1,1} | `P` transitable | **Visitada** → se descarta | [] |
| izquierda | {2,0} | `~` no transitable | Se descarta | [] |

### Llamada #3 · `explorar({3,1}, costo = 3)` · camino: {1,1} → {2,1} → {3,1}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {4,1} | `~` no transitable | Se descarta | [] |
| derecha | {3,2} | `C` transitable, costo 1 | No visitada → **llamada #4** con costo 3 + 1 = **4** | [Ruta A] |
| arriba | {2,1} | `D` transitable | **Visitada** → se descarta | [] |
| izquierda | {3,0} | `~` no transitable | Se descarta | [] |

### Llamada #4 · `explorar({3,2}, costo = 4)` · camino: {1,1} → {2,1} → {3,1} → {3,2}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {4,2} | `~` no transitable | Se descarta | [] |
| derecha | {3,3} | `B` transitable, costo 1 | No visitada → **llamada #5** con costo 4 + 1 = **5** | [Ruta A] |
| arriba | {2,2} | `T` no transitable | Se descarta | [] |
| izquierda | {3,1} | `C` transitable | **Visitada** → se descarta | [] |

### Llamada #5 · `explorar({3,3}, costo = 5)` → **CASO BASE**

La posición actual `{3,3}` es el bote, así que coincide la primera cláusula. `camino` está al revés (`[{3,3}, {3,2}, {3,1}, {2,1}, {1,1}]`) y se invierte con `Enum.reverse`:

> **Ruta A** = `%Ruta{posiciones: [{1,1}, {2,1}, {3,1}, {3,2}, {3,3}], costo: 5}`

### Llamada #6 · `explorar({1,2}, costo = 1)` · camino: {1,1} → {1,2}

Esta rama empieza con `visitadas` = {1,1}, {1,2}. Las posiciones de la Ruta A **no** están marcadas: cada rama lleva su propio `MapSet`.

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {2,2} | `T` no transitable | Se descarta | [] |
| derecha | {1,3} | `C` transitable, costo 1 | No visitada → **llamada #7** con costo 1 + 1 = **2** | [Ruta B] |
| arriba | {0,2} | `~` no transitable | Se descarta | [] |
| izquierda | {1,1} | `P` transitable | **Visitada** → se descarta | [] |

### Llamada #7 · `explorar({1,3}, costo = 2)` · camino: {1,1} → {1,2} → {1,3}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {2,3} | `C` transitable, costo 1 | No visitada → **llamada #8** con costo 2 + 1 = **3** | [Ruta B] |
| derecha | {1,4} | `~` no transitable | Se descarta | [] |
| arriba | {0,3} | `~` no transitable | Se descarta | [] |
| izquierda | {1,2} | `C` transitable | **Visitada** → se descarta | [] |

### Llamada #8 · `explorar({2,3}, costo = 3)` · camino: {1,1} → {1,2} → {1,3} → {2,3}

| Dirección | `siguiente` | `Map.get` | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| abajo | {3,3} | `B` transitable, costo 1 | No visitada → **llamada #9** con costo 3 + 1 = **4** | [Ruta B] |
| derecha | {2,4} | `~` no transitable | Se descarta | [] |
| arriba | {1,3} | `C` transitable | **Visitada** → se descarta | [] |
| izquierda | {2,2} | `T` no transitable | Se descarta | [] |

### Llamada #9 · `explorar({3,3}, costo = 4)` → **CASO BASE**

> **Ruta B** = `%Ruta{posiciones: [{1,1}, {1,2}, {1,3}, {2,3}, {3,3}], costo: 4}`

### Resumen de la prueba

| Llamada | Posición | Costo acumulado | Resultado |
| --- | --- | --- | --- |
| #1 | {1,1} | 0 | [Ruta A, Ruta B] |
| #2 | {2,1} | 2 | [Ruta A] |
| #3 | {3,1} | 3 | [Ruta A] |
| #4 | {3,2} | 4 | [Ruta A] |
| #5 | {3,3} | 5 | Caso base → Ruta A |
| #6 | {1,2} | 1 | [Ruta B] |
| #7 | {1,3} | 2 | [Ruta B] |
| #8 | {2,3} | 3 | [Ruta B] |
| #9 | {3,3} | 4 | Caso base → Ruta B |

**Observaciones:**

- **Nunca se usa la rama `nil` (fuera del mapa).** Como la validación previa garantiza que el borde es agua, la búsqueda se detiene en el agua antes de salirse del mapa. La rama `nil` es una protección por si acaso.
- **La `P` es transitable**, por eso al volver a `{1,1}` no la descarta el patrón `transitable: false` sino la revisión de `visitadas`.
- **El costo del inicio no suma:** la llamada #1 empieza en 0 y cada paso suma el costo de la posición **a la que se entra**. Ruta A: 2 (D) + 1 (C) + 1 (C) + 1 (B) = 5. Ruta B: 1 + 1 + 1 + 1 = 4.
- **No es recursión de cola:** después de cada llamada recursiva todavía hay trabajo pendiente (`flat_map` junta los resultados de las 4 direcciones). Es una recursión en **árbol**, que es lo que permite explorar todas las rutas.

## 4. De las rutas al resultado

`movimientos = length(posiciones) - 1` (se calcula a partir de las posiciones, como pide el enunciado).

| Ruta | Recorrido | Movimientos | Costo |
| --- | --- | --- | --- |
| 1 (A) | {1,1} -> {2,1} -> {3,1} -> {3,2} -> {3,3} | 4 | 5 |
| 2 (B) | {1,1} -> {1,2} -> {1,3} -> {2,3} -> {3,3} | 4 | 4 |

- **Número total de rutas:** 2
- **Rutas más cortas:** las dos (4 movimientos); el programa lista ambas.
- **Ruta de menor costo:** la Ruta 2, con costo 4.

Mapa de `resumen_isla.txt` con la ruta de menor costo marcada:

```
~ ~ ~ ~ ~
~ * * * ~
~ D T * ~
~ C C * ~
~ ~ ~ ~ ~
```

Para reproducirlo: `cd problema2_isla` y `elixir isla.exs datos_prueba/isla_pequena.txt`.

## 5. Árbol de llamadas

### 5.1 Vista resumida: solo las llamadas que se realizan

Cada nodo es una llamada a `explorar/6`. A la derecha está lo que devuelve, después de que `flat_map` junta los resultados de sus hijos.

```
Busqueda.rutas(mapa, {1,1}, {3,3})
└── #1 explorar({1,1}, costo 0)                                  → [Ruta A, Ruta B]
    ├── abajo   → #2 explorar({2,1}, costo 2)                    → [Ruta A]
    │             └── abajo   → #3 explorar({3,1}, costo 3)      → [Ruta A]
    │                           └── derecha → #4 explorar({3,2}, costo 4)   → [Ruta A]
    │                                         └── derecha → #5 explorar({3,3}, costo 5)
    │                                                       ★ CASO BASE → [Ruta A]
    └── derecha → #6 explorar({1,2}, costo 1)                    → [Ruta B]
                  └── derecha → #7 explorar({1,3}, costo 2)      → [Ruta B]
                                └── abajo   → #8 explorar({2,3}, costo 3)   → [Ruta B]
                                              └── abajo   → #9 explorar({3,3}, costo 4)
                                                            ★ CASO BASE → [Ruta B]
```

### 5.2 Vista completa: llamadas y decisiones de cada dirección

Leyenda: `(+n)` costo que se suma al entrar · `──►` llamada recursiva · `✗` dirección descartada · `★` caso base.

```
#1 explorar({1,1}, costo 0)
├── abajo     {2,1} D (+2) ──► #2 explorar({2,1}, costo 2)
│   ├── abajo     {3,1} C (+1) ──► #3 explorar({3,1}, costo 3)
│   │   ├── abajo     {4,1} ~      ✗ no transitable                  → []
│   │   ├── derecha   {3,2} C (+1) ──► #4 explorar({3,2}, costo 4)
│   │   │   ├── abajo     {4,2} ~      ✗ no transitable              → []
│   │   │   ├── derecha   {3,3} B (+1) ──► #5 explorar({3,3}, costo 5)
│   │   │   │                          ★ CASO BASE: es el bote       → [Ruta A]
│   │   │   ├── arriba    {2,2} T      ✗ no transitable              → []
│   │   │   └── izquierda {3,1} C      ✗ visitada                    → []
│   │   │   flat_map → [Ruta A]
│   │   ├── arriba    {2,1} D      ✗ visitada                        → []
│   │   └── izquierda {3,0} ~      ✗ no transitable                  → []
│   │   flat_map → [Ruta A]
│   ├── derecha   {2,2} T      ✗ no transitable                      → []
│   ├── arriba    {1,1} P      ✗ visitada                            → []
│   └── izquierda {2,0} ~      ✗ no transitable                      → []
│   flat_map → [Ruta A]
│
├── derecha   {1,2} C (+1) ──► #6 explorar({1,2}, costo 1)
│   ├── abajo     {2,2} T      ✗ no transitable                      → []
│   ├── derecha   {1,3} C (+1) ──► #7 explorar({1,3}, costo 2)
│   │   ├── abajo     {2,3} C (+1) ──► #8 explorar({2,3}, costo 3)
│   │   │   ├── abajo     {3,3} B (+1) ──► #9 explorar({3,3}, costo 4)
│   │   │   │                          ★ CASO BASE: es el bote       → [Ruta B]
│   │   │   ├── derecha   {2,4} ~      ✗ no transitable              → []
│   │   │   ├── arriba    {1,3} C      ✗ visitada                    → []
│   │   │   └── izquierda {2,2} T      ✗ no transitable              → []
│   │   │   flat_map → [Ruta B]
│   │   ├── derecha   {1,4} ~      ✗ no transitable                  → []
│   │   ├── arriba    {0,3} ~      ✗ no transitable                  → []
│   │   └── izquierda {1,2} C      ✗ visitada                        → []
│   │   flat_map → [Ruta B]
│   ├── arriba    {0,2} ~      ✗ no transitable                      → []
│   └── izquierda {1,1} P      ✗ visitada                            → []
│   flat_map → [Ruta B]
│
├── arriba    {0,1} ~      ✗ no transitable                          → []
└── izquierda {1,0} ~      ✗ no transitable                          → []
flat_map → [Ruta A, Ruta B]
```

### 5.3 Cómo leer el árbol

- **Llamadas realizadas:** 9 a `explorar/6`. Las llamadas #5 y #9 son casos base.
- **Direcciones evaluadas:** las 7 llamadas que no son caso base revisan 4 direcciones cada una (28 en total). 8 terminan en una llamada recursiva y 20 se descartan: 14 por terreno no transitable (agua o árbol, con *pattern matching* sobre `%Terreno{transitable: false}`) y 6 por posición ya visitada.
- **Cómo suben los resultados:** cada caso base devuelve una lista con una ruta; cada nivel junta con `flat_map` las listas de sus 4 direcciones (las descartadas aportan `[]`). En la raíz quedan las dos rutas, en el orden en que se encontraron: primero la de abajo (Ruta A) y después la de la derecha (Ruta B).
- **Ramas independientes:** la rama de la derecha (#6 a #9) no ve las posiciones visitadas por la rama de abajo (#2 a #5), porque cada llamada recibe su propio `MapSet` de visitadas.

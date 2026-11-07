# Problema 1: Rutas entre ciudades — pruebas de escritorio, árboles y resultados

Programa: `problema1_rutas/rutas_ciudades.exs`. Cubre los tres puntos del Problema 1:

| Punto | Función | Dónde está la prueba |
| --- | --- | --- |
| Búsqueda principal con recursión | `buscar_rutas_recursivo/5` | Sección 2 de este documento |
| Stream infinito: ciudades alcanzables | `stream_alcanzables/2` y `calcular_alcance_hasta_estabilizar/2` | Sección 3 de este documento |
| Validación previa con recursión: depuración | `Depuracion.depurar/1` (`problema1_rutas/depuracion.exs`) | `pruebas_escritorio_validaciones.md`, sección 1 |

Las pruebas se construyeron a partir de una traza real de la ejecución (rastreador `:dbg` de Erlang).

---

## 1. Datos de entrada y grafo

`conexiones.csv` (el del enunciado):

```
# ciudad_a,ciudad_b,distancia_km      ← línea 1
Armenia,Pereira,45                    ← línea 2
Pereira,Manizales,52                  ← línea 3
Armenia,Cartago,60                    ← línea 4
Cartago,Pereira,25                    ← línea 5
Pereira,Armenia,45                    ← línea 6: repetida, se descarta
Manizales,Manizales,0                 ← línea 7: consigo misma, se descarta
Cartago,Pereira,30                    ← línea 8: distancia distinta, se descarta
```

`consultas.txt`:

```
Armenia,Manizales
Cartago,Manizales
```

Después de la depuración quedan las líneas 2 a 5, y `construir_grafo/1` arma la lista de vecinos de cada ciudad, en ambos sentidos y en el orden del archivo:

```elixir
%{
  "Armenia"   => [{"Pereira", 45}, {"Cartago", 60}],
  "Pereira"   => [{"Armenia", 45}, {"Manizales", 52}, {"Cartago", 25}],
  "Cartago"   => [{"Armenia", 60}, {"Pereira", 25}],
  "Manizales" => [{"Pereira", 52}]
}
```

```
        45            52
Armenia ──── Pereira ──── Manizales
    \          /
  60 \        / 25
      Cartago
```

Caso pequeño y representativo para las pruebas: la consulta **Armenia → Manizales**. Con 4 ciudades aparecen todas las decisiones de la búsqueda: avanzar a un vecino, descartar un vecino que ya está en el camino, llegar al destino (caso base) y quedar en un camino sin salida. Además, las dos rutas tienen distinto número de ciudades y distinta distancia.

---

## 2. Búsqueda de rutas con recursión

### 2.1 Cómo funciona `buscar_rutas_recursivo/5`

```elixir
buscar_rutas_recursivo(actual, destino, grafo, camino, distancia)
```

| Parámetro | Qué guarda |
| --- | --- |
| `actual` | La ciudad donde va la ruta en esta llamada |
| `destino` | La ciudad a la que se quiere llegar (no cambia) |
| `grafo` | El mapa de vecinos de la sección 1 |
| `camino` | Las ciudades recorridas, **al revés** (la última va primero) |
| `distancia` | Kilómetros acumulados hasta `actual` |

Cláusulas, en el orden en que Elixir las prueba:

1. **Caso base** `when actual == destino`: se llegó. Devuelve una lista con una ruta: `[%Ruta{ciudades: Enum.reverse(camino), distancia: distancia}]`.
2. **Caso recursivo**: recorre los vecinos de `actual` con `Enum.flat_map`. Para cada `{vecino, tramo}`:
   - si `vecino in camino` → `[]` (una ciudad no puede repetirse en la ruta);
   - si no → llamada recursiva con `[vecino | camino]` y `distancia + tramo`.

La primera llamada la hace `resolver_consulta/3`: `buscar_rutas_recursivo("Armenia", "Manizales", grafo, ["Armenia"], 0)`.

### 2.2 Prueba de escritorio (Armenia → Manizales)

#### Llamada #1 · `actual = Armenia`, distancia 0 · camino: Armenia

| Vecino | Tramo | ¿Está en el camino? | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| Pereira | 45 | No | **Llamada #2** con distancia 0 + 45 = **45** | [Ruta 1] |
| Cartago | 60 | No | **Llamada #5** con distancia 0 + 60 = **60** | [Ruta 2] |

`flat_map` → **[Ruta 1, Ruta 2]** (resultado final)

#### Llamada #2 · `actual = Pereira`, distancia 45 · camino: Armenia → Pereira

| Vecino | Tramo | ¿Está en el camino? | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| Armenia | 45 | **Sí** | Se descarta | [] |
| Manizales | 52 | No | **Llamada #3** con distancia 45 + 52 = **97** | [Ruta 1] |
| Cartago | 25 | No | **Llamada #4** con distancia 45 + 25 = **70** | [] |

#### Llamada #3 · `actual = Manizales` → **CASO BASE**

`Manizales == destino`, así que coincide la cláusula con el guard. `camino` está al revés (`["Manizales", "Pereira", "Armenia"]`) y se invierte con `Enum.reverse`:

> **Ruta 1** = `%Ruta{ciudades: ["Armenia", "Pereira", "Manizales"], distancia: 97}`

#### Llamada #4 · `actual = Cartago`, distancia 70 · camino: Armenia → Pereira → Cartago

| Vecino | Tramo | ¿Está en el camino? | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| Armenia | 60 | **Sí** | Se descarta | [] |
| Pereira | 25 | **Sí** | Se descarta | [] |

`flat_map` → **[]**. Es un **camino sin salida**: todos los vecinos de Cartago ya están en la ruta. La llamada devuelve una lista vacía y la búsqueda **retrocede** a la llamada #2.

#### Llamada #5 · `actual = Cartago`, distancia 60 · camino: Armenia → Cartago

| Vecino | Tramo | ¿Está en el camino? | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| Armenia | 60 | **Sí** | Se descarta | [] |
| Pereira | 25 | No | **Llamada #6** con distancia 60 + 25 = **85** | [Ruta 2] |

#### Llamada #6 · `actual = Pereira`, distancia 85 · camino: Armenia → Cartago → Pereira

| Vecino | Tramo | ¿Está en el camino? | Decisión | Devuelve |
| --- | --- | --- | --- | --- |
| Armenia | 45 | **Sí** | Se descarta | [] |
| Manizales | 52 | No | **Llamada #7** con distancia 85 + 52 = **137** | [Ruta 2] |
| Cartago | 25 | **Sí** | Se descarta | [] |

#### Llamada #7 · `actual = Manizales` → **CASO BASE**

> **Ruta 2** = `%Ruta{ciudades: ["Armenia", "Cartago", "Pereira", "Manizales"], distancia: 137}`

#### Resumen de la prueba

| Llamada | Ciudad actual | Camino | Distancia | Resultado |
| --- | --- | --- | --- | --- |
| #1 | Armenia | Armenia | 0 | [Ruta 1, Ruta 2] |
| #2 | Pereira | Armenia → Pereira | 45 | [Ruta 1] |
| #3 | Manizales | Armenia → Pereira → Manizales | 97 | Caso base → Ruta 1 |
| #4 | Cartago | Armenia → Pereira → Cartago | 70 | [] (sin salida) |
| #5 | Cartago | Armenia → Cartago | 60 | [Ruta 2] |
| #6 | Pereira | Armenia → Cartago → Pereira | 85 | [Ruta 2] |
| #7 | Manizales | Armenia → Cartago → Pereira → Manizales | 137 | Caso base → Ruta 2 |

**Observaciones:**

- **Cartago se visita en dos llamadas distintas (#4 y #5)**, porque cada una pertenece a una ruta diferente. Lo que no se permite es repetir una ciudad **dentro** de la misma ruta, y eso es lo que revisa `vecino in camino`.
- **La llamada #4 muestra el retroceso (*backtracking*):** desde Cartago ya no hay a dónde ir, devuelve `[]` y `flat_map` de la llamada #2 simplemente no agrega nada.
- **El camino se guarda al revés** (`[vecino | camino]`, que agrega al inicio en O(1)) y se invierte una sola vez en el caso base. Es la misma idea de "Invertir lista" de la guía 08.
- **No es recursión de cola:** después de cada llamada recursiva todavía hay trabajo pendiente (`flat_map` junta los resultados de todos los vecinos). Es una recursión en **árbol**.

### 2.3 Árbol de llamadas

Leyenda: `──►` llamada recursiva · `✗ en camino` vecino descartado · `★` caso base · `=` lo que devuelve la llamada.

```
buscar_rutas_recursivo("Armenia", "Manizales", grafo, ["Armenia"], 0)
└── #1 actual = Armenia, dist 0
    ├── Pereira (+45) ──► #2 actual = Pereira, dist 45
    │   ├── Armenia (+45)    ✗ en camino                         → []
    │   ├── Manizales (+52) ──► #3 actual = Manizales, dist 97
    │   │                       ★ CASO BASE: actual == destino   → [Ruta 1]
    │   └── Cartago (+25) ──► #4 actual = Cartago, dist 70
    │       ├── Armenia (+60)    ✗ en camino                     → []
    │       └── Pereira (+25)    ✗ en camino                     → []
    │       = []   (camino sin salida: se retrocede)
    │   = [Ruta 1]
    │
    └── Cartago (+60) ──► #5 actual = Cartago, dist 60
        ├── Armenia (+60)    ✗ en camino                         → []
        └── Pereira (+25) ──► #6 actual = Pereira, dist 85
            ├── Armenia (+45)    ✗ en camino                     → []
            ├── Manizales (+52) ──► #7 actual = Manizales, dist 137
            │                       ★ CASO BASE: actual == destino → [Ruta 2]
            └── Cartago (+25)    ✗ en camino                     → []
            = [Ruta 2]
        = [Ruta 2]
    = [Ruta 1] ++ [Ruta 2] = [Ruta 1, Ruta 2]
```

Vista resumida (solo las llamadas recursivas):

```
                         #1 Armenia (0)
                        /              \
                 +45   /                \  +60
                      /                  \
            #2 Pereira (45)          #5 Cartago (60)
             /          \                  |  +25
       +52  /            \ +25             |
           /              \         #6 Pereira (85)
  ★ #3 Manizales (97)   #4 Cartago (70)     |  +52
       Ruta 1            sin salida  ★ #7 Manizales (137)
                            []             Ruta 2
```

### 2.4 De las rutas al resultado

| Ruta | Recorrido | Ciudades | Distancia |
| --- | --- | --- | --- |
| 1 | Armenia -> Pereira -> Manizales | 3 | 97 km |
| 2 | Armenia -> Cartago -> Pereira -> Manizales | 4 | 137 km |

- **Número de rutas:** 2
- **Ruta más corta** (menos ciudades): la Ruta 1, con 3 ciudades.
- **Ruta de menor distancia:** la Ruta 1, con 97 km.

En esta consulta la más corta y la de menor distancia coinciden. En la segunda consulta (Cartago → Manizales) también coinciden: Cartago -> Pereira -> Manizales, con 3 ciudades y 77 km, frente a Cartago -> Armenia -> Pereira -> Manizales, con 4 ciudades y 157 km.

---

## 3. Stream infinito: ciudades alcanzables

### 3.1 Cómo funciona

```elixir
Stream.iterate(MapSet.new([origen]), fn ciudades_actuales ->
  # agrega a ciudades_actuales los vecinos de cada una de ellas
end)
```

- **Paso 0:** solo el origen.
- **Cada paso siguiente:** el paso anterior más los vecinos de todas sus ciudades.
- La secuencia es **infinita**: después de estabilizarse sigue produciendo el mismo conjunto para siempre. Por eso se consume solo lo necesario.

`calcular_alcance_hasta_estabilizar/2` lo consume así:

```elixir
origen
|> stream_alcanzables(grafo)        # p0, p1, p2, p3, ...   (infinito)
|> Stream.chunk_every(2, 1)         # [p0,p1], [p1,p2], [p2,p3], ...   (pares consecutivos)
|> Stream.with_index(0)             # {[p0,p1], 0}, {[p1,p2], 1}, ...
|> Enum.reduce_while(...)           # escribe "Paso n" y se detiene cuando actual == siguiente
```

`chunk_every(2, 1)` arma ventanas de 2 elementos que avanzan de a 1. Así cada paso se compara con el siguiente. `Enum.reduce_while` es la única función que consume el stream, y al devolver `{:halt, ...}` deja de pedir elementos.

### 3.2 Prueba de escritorio (alcance desde Armenia)

Cálculo de cada paso con `Stream.iterate`:

| Paso | Se calcula a partir de | Vecinos que se agregan | Conjunto |
| --- | --- | --- | --- |
| p0 | (valor inicial) | — | {Armenia} |
| p1 | p0 | Armenia → Pereira, Cartago | {Armenia, Cartago, Pereira} |
| p2 | p1 | Armenia → Pereira, Cartago · Cartago → Armenia, Pereira · Pereira → Armenia, **Manizales**, Cartago | {Armenia, Cartago, Manizales, Pereira} |
| p3 | p2 | Manizales → Pereira, y las demás como en p2: **ninguna nueva** | {Armenia, Cartago, Manizales, Pereira} |

Consumo con `Enum.reduce_while` (cada fila es un elemento que pide):

| Índice (paso) | Par `[actual, siguiente]` | ¿`actual == siguiente`? | Qué escribe en `alcance.txt` | Decisión |
| --- | --- | --- | --- | --- |
| 0 | [p0, p1] | No | `Paso 0: Armenia` | `{:cont, p1}` |
| 1 | [p1, p2] | No | `Paso 1: Armenia, Cartago, Pereira` | `{:cont, p2}` |
| 2 | [p2, p3] | **Sí** | `Paso 2: Armenia, Cartago, Manizales, Pereira` y `Se estabiliza en el paso 2` | `{:halt, p2}` |

**Resultado:** el conjunto final es p2. `MapSet.member?(p2, "Manizales")` es `true`, así que se ejecuta la búsqueda recursiva de la sección 2.

**Elementos calculados:** p0 (valor inicial) más **3 llamadas** a la función de `Stream.iterate` (p1, p2 y p3). El paso **p4 nunca se calcula**. Así se cumple lo que pide el enunciado: *"el último paso que se calcula es el primero que se repite"*. Se calcula p3 solo para descubrir que es igual a p2. Lo verificamos contando las llamadas a la función de `iterate`.

### 3.3 Diagrama del consumo perezoso

```
Stream.iterate:      p0 ──f──► p1 ──f──► p2 ──f──► p3 ··· p4 (nunca se calcula)
                   {Arm}    {Arm,Car,  {Arm,Car,   {Arm,Car,
                             Per}       Man,Per}    Man,Per}

chunk_every(2,1):  [p0,p1]   [p1,p2]   [p2,p3]
                      │         │         │
reduce_while:      paso 0    paso 1    paso 2
                   p0≠p1     p1≠p2     p2 = p3
                   :cont     :cont     :halt ──► resultado: p2
```

### 3.4 Caso sin rutas: el destino no es alcanzable

Con un grafo donde Armenia solo se conecta con Pereira, y Salento solo con Filandia, la consulta **Armenia → Salento** produce:

```
=== Alcance desde Armenia ===
Paso 0: Armenia
Paso 1: Armenia, Pereira
Se estabiliza en el paso 1
```

Salento no está en el conjunto final {Armenia, Pereira}, así que la consulta se reporta como `Sin rutas posibles entre origen y destino.` y **no se ejecuta la búsqueda recursiva**, como pide el enunciado.

---

## 4. Datos y resultados del Problema 1

Ejecución: `elixir problema1_rutas/rutas_ciudades.exs` con los archivos de la sección 1.

**Búsqueda (`rutas_encontradas.txt`):**

```
=== Armenia -> Manizales ===
Ruta 1: Armenia -> Pereira -> Manizales (3 ciudades, 97 km)
Ruta 2: Armenia -> Cartago -> Pereira -> Manizales (4 ciudades, 137 km)
Número de rutas: 2
Ruta más corta: Armenia -> Pereira -> Manizales
Ruta de menor distancia: Armenia -> Pereira -> Manizales (97 km)

=== Cartago -> Manizales ===
Ruta 1: Cartago -> Armenia -> Pereira -> Manizales (4 ciudades, 157 km)
Ruta 2: Cartago -> Pereira -> Manizales (3 ciudades, 77 km)
Número de rutas: 2
Ruta más corta: Cartago -> Pereira -> Manizales
Ruta de menor distancia: Cartago -> Pereira -> Manizales (77 km)
```

**Stream infinito (`alcance.txt`):**

```
=== Alcance desde Armenia ===
Paso 0: Armenia
Paso 1: Armenia, Cartago, Pereira
Paso 2: Armenia, Cartago, Manizales, Pereira
Se estabiliza en el paso 2

=== Alcance desde Cartago ===
Paso 0: Cartago
Paso 1: Armenia, Cartago, Pereira
Paso 2: Armenia, Cartago, Manizales, Pereira
Se estabiliza en el paso 2
```

**Validación (`depuracion_conexiones.txt`):**

```
Línea 6: Pereira,Armenia,45 -> repetida (línea 2); se descarta
Línea 7: Manizales,Manizales,0 -> conecta una ciudad consigo misma; se descarta
Línea 8: Cartago,Pereira,30 -> distancia distinta a la de la línea 5 (25); se conserva la de la línea 5
```

**Líneas mal formadas (`errores_conexiones.txt`):** vacío con el archivo del enunciado, porque no tiene líneas mal formadas. Con un archivo de prueba con errores:

```
Línea 3: Pereira,Manizales -> Se esperaban tres campos: origen,destino,distancia
Línea 4: Armenia,Cartago,abc -> La distancia debe ser un entero no negativo
Línea 6: ,Pereira,3 -> Falta la ciudad de origen
Línea 7: Cartago,Pereira,-5 -> La distancia debe ser un entero no negativo
```

Todas las salidas con los archivos del enunciado coinciden exactamente con las del enunciado.

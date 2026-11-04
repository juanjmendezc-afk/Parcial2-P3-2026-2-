# Validaciones con recursión: pruebas de escritorio, árboles de llamadas y resultados

Responsable: rol transversal. Cubre el punto **"validación previa con recursión"** de los dos problemas:

- Problema 1: `Depuracion.depurar/1` (`problema1_rutas/depuracion.exs`)
- Problema 2: `ValidacionIsla.validar/2` (`problema2_isla/validacion_isla.exs`)

Los casos de prueba están en `docs/casos_validacion/`. Para regenerar todas las salidas:

```bash
cd docs/casos_validacion
elixir probar_validaciones.exs
```

Los árboles se construyeron a partir de una traza real de la ejecución (rastreador `:dbg` de Erlang), no a mano.

---

## 1. Problema 1: depuración de conexiones

### 1.1 Caso pequeño y representativo

Archivo `conexiones_pequeno.csv`: cuatro conexiones, una por cada decisión posible de la función.

| Línea del archivo | Contenido | Qué se espera |
| --- | --- | --- |
| 1 | `# Caso pequeño para la prueba de escritorio…` | Comentario: no llega a la función |
| 2 | `Armenia,Pereira,45` | Se conserva (primera vez que aparece el par) |
| 3 | `Pereira,Armenia,45` | Repetida en sentido contrario, misma distancia |
| 4 | `Pereira,Pereira,0` | Conecta una ciudad consigo misma |
| 5 | `Pereira,Armenia,50` | Mismo par, distancia distinta |

Entrada que recibe `Depuracion.depurar/1` (abreviada como L2 a L5):

```elixir
[
  {2, "Armenia,Pereira,45", %{origen: "Armenia", destino: "Pereira", distancia: 45}},   # L2
  {3, "Pereira,Armenia,45", %{origen: "Pereira", destino: "Armenia", distancia: 45}},   # L3
  {4, "Pereira,Pereira,0",  %{origen: "Pereira", destino: "Pereira", distancia: 0}},    # L4
  {5, "Pereira,Armenia,50", %{origen: "Pereira", destino: "Armenia", distancia: 50}}    # L5
]
```

### 1.2 Prueba de escritorio

`depurar/1` llama a `depurar/4` con los acumuladores vacíos: `vistas = %{}`, `conservadas = []`, `reportes = []`.

| # | Cabeza de la lista | ¿`origen == destino`? | `clave_par` | `Map.get(vistas, par)` | Decisión | `vistas` después | `conservadas` | `reportes` |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | L2 `Armenia,Pereira,45` | No | `{"Armenia","Pereira"}` | `nil` | **Caso 4**: se conserva y se recuerda | `%{{"Armenia","Pereira"} => {2, 45}}` | `[L2]` | `[]` |
| 2 | L3 `Pereira,Armenia,45` | No | `{"Armenia","Pereira"}` | `{2, 45}`: 45 coincide con `^km` | **Caso 2**: repetida (línea 2) | sin cambio | `[L2]` | `[R3]` |
| 3 | L4 `Pereira,Pereira,0` | **Sí** | no se calcula | no se consulta | **Caso 1**: ciudad consigo misma | sin cambio | `[L2]` | `[R4, R3]` |
| 4 | L5 `Pereira,Armenia,50` | No | `{"Armenia","Pereira"}` | `{2, 45}`: 45 ≠ 50 | **Caso 3**: distancia distinta; se conserva la de la línea 2 | sin cambio | `[L2]` | `[R5, R4, R3]` |
| 5 | `[]` | — | — | — | **Caso base**: se invierten los acumuladores | — | `[L2]` | `[R3, R4, R5]` |

Donde:

- R3 = `"Línea 3: Pereira,Armenia,45 -> repetida (línea 2); se descarta"`
- R4 = `"Línea 4: Pereira,Pereira,0 -> conecta una ciudad consigo misma; se descarta"`
- R5 = `"Línea 5: Pereira,Armenia,50 -> distancia distinta a la de la línea 2 (45); se conserva la de la línea 2"`

**Observaciones:**

- `clave_par` ordena las ciudades alfabéticamente. Por eso `Armenia,Pereira` y `Pereira,Armenia` producen la misma clave y la repetición se detecta en cualquier sentido.
- En la llamada 3 nunca se llama a `clave_par`: la cláusula `%{origen: ciudad, destino: ciudad}` (la misma variable dos veces) atrapa la conexión antes.
- Los reportes se agregan al **inicio** de la lista (`[reporte | reportes]`, operación O(1)), así que quedan al revés. En el caso base se invierten **una sola vez** con `invertir/1`, una función recursiva propia (no se usa `Enum.reverse/1`).

### 1.3 Árbol de llamadas

```
depurar([L2, L3, L4, L5])
└── depurar([L2, L3, L4, L5], %{}, [], [])
    │   L2: Armenia ≠ Pereira
    │   clave_par("Armenia", "Pereira") = {"Armenia", "Pereira"}
    │   Map.get(vistas, par) = nil                          → CASO 4: se conserva
    │
    └── depurar([L3, L4, L5], %{{A,P} => {2,45}}, [L2], [])
        │   L3: Pereira ≠ Armenia
        │   clave_par("Pereira", "Armenia") = {"Armenia", "Pereira"}
        │   Map.get(vistas, par) = {2, 45} y 45 = ^km        → CASO 2: repetida
        │
        └── depurar([L4, L5], %{{A,P} => {2,45}}, [L2], [R3])
            │   L4: origen = destino = "Pereira"             → CASO 1: consigo misma
            │
            └── depurar([L5], %{{A,P} => {2,45}}, [L2], [R4, R3])
                │   L5: Pereira ≠ Armenia
                │   clave_par("Pereira", "Armenia") = {"Armenia", "Pereira"}
                │   Map.get(vistas, par) = {2, 45} y 45 ≠ 50  → CASO 3: distancia distinta
                │
                └── depurar([], %{{A,P} => {2,45}}, [L2], [R5, R4, R3])   ← CASO BASE
                    ├── invertir([L2])           = [L2]
                    └── invertir([R5, R4, R3])   = [R3, R4, R5]

Resultado: {[L2], [R3, R4, R5]}
```

Árbol de `invertir([R5, R4, R3])` (recursión de cola con acumulador):

```
invertir([R5, R4, R3])
└── invertir([R5, R4, R3], [])
    └── invertir([R4, R3], [R5])
        └── invertir([R3], [R4, R5])
            └── invertir([], [R3, R4, R5])   ← CASO BASE: devuelve el acumulado
```

> **Nota para la sustentación.** `depurar/4` e `invertir/2` son recursivas **de cola**: la llamada recursiva es lo último que hace cada cláusula, así que no se acumula trabajo pendiente en la pila. En el árbol se dibujan anidadas para mostrar el orden de las llamadas.

### 1.4 Datos y resultados

| Entrada | Salida obtenida |
| --- | --- |
| `conexiones_pequeno.csv` | `salidas/depuracion_conexiones_pequeno.txt` |
| `conexiones_enunciado.csv` (el ejemplo del enunciado) | `salidas/depuracion_conexiones_enunciado.txt` |

Salida con el ejemplo del enunciado (coincide exactamente con la del enunciado):

```
Línea 6: Pereira,Armenia,45 -> repetida (línea 2); se descarta
Línea 7: Manizales,Manizales,0 -> conecta una ciudad consigo misma; se descarta
Línea 8: Cartago,Pereira,30 -> distancia distinta a la de la línea 5 (25); se conserva la de la línea 5
```

Conexiones conservadas: líneas 2, 3, 4 y 5.

---

## 2. Problema 2: validación del mapa de la isla

### 2.1 Caso pequeño y representativo

Archivo `isla_pequena_invalida.txt`: un mapa de 3 filas con **un problema de cada tipo**.

```
          col 0  col 1  col 2  col 3
fila 0      ~      ~      ~      ~
fila 1      ~      P      X      ~
fila 2      ~      C      ~             ← solo 3 posiciones
```

| Problema plantado | Dónde |
| --- | --- |
| Fila con un número distinto de posiciones | Fila 2 (3 en lugar de 4) |
| Símbolo que no está en `terrenos.csv` | `X` en {1,2} |
| Borde que no es agua | `C` en {2,1} (la fila 2 es la última, así que toda ella es borde) |
| Falta el bote | No hay ninguna posición cuyo terreno se llame `bote` |

Valores iniciales calculados en `validar/2`:

- `esperadas = contar(primera_fila) = 4`
- `ultima_fila = contar(filas) - 1 = 2`

### 2.2 Prueba de escritorio

Revisión de cada fila (`revisar_tamano/3`):

| Fila | `tamano` | ¿Igual a `esperadas` (4)? | Hallazgo |
| --- | --- | --- | --- |
| 0 | 4 | Sí | — |
| 1 | 4 | Sí | — |
| 2 | 3 | **No** | `Fila 2: tiene 3 posiciones; se esperaban 4` |

Revisión de cada posición (`revisar_columnas/5`, que aplica `revisar_simbolo`, `revisar_borde` y `registrar_especial`):

| Posición | Símbolo | ¿Está en terrenos? | ¿Es borde? | ¿Es agua? | ¿Inicio o bote? | Hallazgo |
| --- | --- | --- | --- | --- | --- | --- |
| {0,0} {0,1} {0,2} {0,3} | `~` | Sí | Sí (fila 0) | Sí | No | — |
| {1,0} | `~` | Sí | Sí (columna 0) | Sí | No | — |
| {1,1} | `P` | Sí | No | — | **Inicio** | `inicios = [{1,1}]` |
| {1,2} | `X` | **No** | No | — | No | `Posición {1,2}: el símbolo X no está en terrenos.csv` |
| {1,3} | `~` | Sí | Sí (última columna) | Sí | No | — |
| {2,0} | `~` | Sí | Sí (última fila) | Sí | No | — |
| {2,1} | `C` | Sí | Sí (última fila) | **No** | No | `Posición {2,1}: el borde debe ser agua y contiene C` |
| {2,2} | `~` | Sí | Sí | Sí | No | — |

Revisión final (`revisar_unico/3`):

| Qué | Posiciones encontradas | Cláusula que coincide | Hallazgo |
| --- | --- | --- | --- |
| Inicio | `[{1,1}]` | `[_una]`: exactamente una | — |
| Bote | `[]` | `[]`: ninguna; `simbolo_de(terrenos, "bote") = "B"` | `No hay bote B` |

Los hallazgos se juntan en este orden: tamaño de filas, símbolos, borde, inicio y bote.

**Observaciones:**

- `X` en {1,2} no es borde, porque la fila 1 tiene 4 posiciones y su última columna es la 3. Por eso solo se reporta como símbolo desconocido.
- El borde se calcula con el tamaño **de cada fila**, así que en la fila 2 (más corta) la última columna es la 2.
- El inicio, el bote y el agua se reconocen por el **nombre** del terreno (`es?/3` y `simbolo_de/2`), nunca por la letra. El mensaje "No hay bote B" toma la `B` de `terrenos.csv`.

### 2.3 Árbol de llamadas

```
validar(filas, terrenos)
│   esperadas = contar(fila 0) = 4,  ultima_fila = contar(filas) - 1 = 2
│
├── revisar_filas([fila0, fila1, fila2], 0, acum)
│   ├── revisar_tamano(fila 0, tamano 4)          → igual a 4: sin hallazgo
│   ├── revisar_columnas(["~","~","~","~"], fila 0, col 0)
│   │   └── col 1 → col 2 → col 3 → [] (CASO BASE)       todas agua en el borde: sin hallazgos
│   │
│   └── revisar_filas([fila1, fila2], 1, acum)
│       ├── revisar_tamano(fila 1, tamano 4)      → igual a 4: sin hallazgo
│       ├── revisar_columnas(["~","P","X","~"], fila 1, col 0)   {1,0} ~ borde y agua: ok
│       │   └── revisar_columnas(["P","X","~"], col 1)          {1,1} P → inicios = [{1,1}]
│       │       └── revisar_columnas(["X","~"], col 2)          {1,2} X → no está en terrenos.csv
│       │           └── revisar_columnas(["~"], col 3)          {1,3} ~ borde y agua: ok
│       │               └── revisar_columnas([], col 4)         CASO BASE
│       │
│       └── revisar_filas([fila2], 2, acum)
│           ├── revisar_tamano(fila 2, tamano 3)  → 3 ≠ 4: "Fila 2: tiene 3 posiciones…"
│           ├── revisar_columnas(["~","C","~"], fila 2, col 0)   {2,0} ~ borde y agua: ok
│           │   └── revisar_columnas(["C","~"], col 1)          {2,1} C borde y no es agua → hallazgo
│           │       └── revisar_columnas(["~"], col 2)          {2,2} ~ borde y agua: ok
│           │           └── revisar_columnas([], col 3)         CASO BASE
│           │
│           └── revisar_filas([], 3, acum)        CASO BASE: devuelve el acumulado
│
├── revisar_unico([{1,1}], terrenos, "inicio")   → [_una]: []
└── revisar_unico([], terrenos, "bote")          → []: ["No hay bote B"]

Resultado:
{:error, ["Fila 2: tiene 3 posiciones; se esperaban 4",
          "Posición {1,2}: el símbolo X no está en terrenos.csv",
          "Posición {2,1}: el borde debe ser agua y contiene C",
          "No hay bote B"]}
```

Hay dos niveles de recursión: `revisar_filas/3` recorre las filas y, dentro de cada fila, `revisar_columnas/5` recorre las posiciones. Ninguno usa `Enum` ni `Stream`.

### 2.4 Caso pequeño válido

Archivo `isla_pequena_valida.txt`:

```
~ ~ ~ ~
~ P B ~
~ ~ ~ ~
```

Todas las filas tienen 4 posiciones, todos los símbolos existen, el borde es agua, hay un solo inicio ({1,1}) y un solo bote ({1,2}). Resultado: `:ok`, y `validacion_isla.txt` contiene `El mapa es válido`.

### 2.5 Datos y resultados

| Entrada | Salida obtenida |
| --- | --- |
| `isla_pequena_invalida.txt` | `salidas/validacion_isla_pequena_invalida.txt` |
| `isla_pequena_valida.txt` | `salidas/validacion_isla_pequena_valida.txt` |
| `isla_enunciado.txt` (el mapa del enunciado) | `salidas/validacion_isla_enunciado.txt`: `El mapa es válido` |
| `isla_errores_enunciado.txt` (con los errores del ejemplo) | `salidas/validacion_isla_errores_enunciado.txt` |

Salida con los errores del ejemplo del enunciado (coincide exactamente con la del enunciado):

```
Fila 3: tiene 6 posiciones; se esperaban 7
Posición {0,4}: el borde debe ser agua y contiene C
Hay 2 posiciones iniciales P: {1,1} y {4,3}
```

Todos los casos usan `terrenos.csv` (el del enunciado).

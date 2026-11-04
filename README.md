# Parcial 2 — Programación III (Elixir)

Universidad del Quindío · 2026-2 · Docente: Carlos Andrés Flórez Villarraga

## Integrantes

| Nombre | Usuario GitHub | Responsabilidad |
| --- | --- | --- |
| Juanjo Méndez _(completar nombre)_ | @juanjmendezc-afk | Transversal: módulo común de archivos, validaciones recursivas de ambos problemas y armado del PDF |
| _pendiente_ | _pendiente_ | Problema 1: Rutas entre ciudades |
| _pendiente_ | _pendiente_ | Problema 2: Escapar de la isla |

## Problemas elegidos

**1. Rutas entre ciudades** y **2. Escapar de la isla**.

## Estructura

Cada archivo tiene un solo responsable, para que los tres podamos hacer push sin conflictos.

```
comun/archivo.exs              ← Transversal: lectura y escritura de archivos (único módulo con efectos en disco)
problema1_rutas/
  rutas.exs                    ← Problema 1: main, structs, grafo, alcance, búsqueda
  depuracion.exs               ← Transversal: validación recursiva de las conexiones
  conexiones.csv, consultas.txt
problema2_isla/
  isla.exs                     ← Problema 2: main, structs, búsqueda
  validacion_isla.exs          ← Transversal: validación recursiva del mapa
  isla.txt, terrenos.csv
docs/                          ← pruebas de escritorio y árboles de llamadas
  pruebas_escritorio_validaciones.md   ← Transversal: validaciones de ambos problemas
  casos_validacion/                    ← Transversal: casos de prueba, probar_validaciones.exs y salidas/
```

### Módulo común `Archivo` (`comun/archivo.exs`)

Se carga al inicio de cada programa con:

```elixir
Code.require_file("../comun/archivo.exs", __DIR__)
```

| Función | Qué hace | Devuelve |
| --- | --- | --- |
| `Archivo.leer_lineas(ruta)` | Lee con `File.stream!/1`, numera todas las líneas desde 1, recorta espacios y descarta vacías y comentarios (`#`). Perezoso. | `{:ok, stream de {numero_linea, texto}}` o `{:error, mensaje}` |
| `Archivo.escribir_lineas(ruta, lineas)` | Crea o reemplaza el archivo y escribe una línea por elemento (lista o stream). | `:ok` o `{:error, mensaje}` |
| `Archivo.emitir(ruta, lineas)` | Igual que `escribir_lineas/2`, pero además imprime cada línea en pantalla. | `:ok` o `{:error, mensaje}` |

### Validaciones con recursión (sin `Enum` ni `Stream`)

| Función | Recibe | Devuelve |
| --- | --- | --- |
| `Depuracion.depurar(conexiones)` (`problema1_rutas/depuracion.exs`) | Lista de `{numero_linea, texto, conexion}` en el orden del archivo; `conexion` tiene `origen`, `destino` y `distancia` (entero) | `{conservadas, reportes}`: las tuplas que se conservan (mismo orden) y una línea por corrección |
| `Depuracion.lineas_reporte(reportes)` | Los reportes anteriores | Líneas para `depuracion_conexiones.txt` |
| `ValidacionIsla.validar(filas, terrenos)` (`problema2_isla/validacion_isla.exs`) | `filas`: lista de filas, cada una lista de símbolos; `terrenos`: mapa `%{simbolo => terreno}` (con campo `nombre`) | `:ok` o `{:error, problemas}` |
| `ValidacionIsla.lineas_reporte(resultado)` | El resultado anterior | Líneas para `validacion_isla.txt` |

Uso esperado en el Problema 1 (después de `Conexion.parse/1`, que también conserva el número de línea y el texto):

```elixir
{conservadas, reportes} = Depuracion.depurar(conexiones_numeradas)
Archivo.escribir_lineas(Path.join(__DIR__, "depuracion_conexiones.txt"), Depuracion.lineas_reporte(reportes))
# El grafo se construye solo con `conservadas`
```

Uso esperado en el Problema 2:

```elixir
resultado = ValidacionIsla.validar(filas, terrenos)
Archivo.escribir_lineas(Path.join(__DIR__, "validacion_isla.txt"), ValidacionIsla.lineas_reporte(resultado))
# Si resultado es {:error, _}, no se realiza la búsqueda
```

Versión usada para probar: Elixir 1.19.4 (Erlang/OTP 28).

### Acuerdos de diseño

- Las validaciones con recursión no usan `Enum` ni `Stream` (tampoco `length/1` ni `Enum.reverse/1`; se usan funciones recursivas propias). Sí se permite `Map`.
- Problema 2: los símbolos y costos no se escriben en el código. El inicio, el bote y el agua se reconocen por la columna `nombre` de `terrenos.csv` (`inicio`, `bote`, `agua`).
- Si una validación no encuentra nada que reportar, su archivo de salida se crea igual con una línea que lo indica.
- En la validación del mapa, la cantidad de posiciones esperada por fila es la de la primera fila.

## Cómo ejecutar

Cada problema está en su propia carpeta, con su programa `.exs` y sus archivos de entrada.

```bash
elixir nombre_del_programa.exs
```

Las rutas se construyen con `Path.join(__DIR__, ...)`, así que el programa funciona sin importar desde qué carpeta se ejecute.

## Reglas del repositorio

1. Antes de empezar a trabajar y antes de hacer push: **Fetch/Pull origin**.
2. Cada integrante trabaja en la carpeta de su parte; no editar archivos de otro sin avisar.
3. Commits pequeños, con mensajes claros (por ejemplo: `Problema 1: depuración recursiva de conexiones`).

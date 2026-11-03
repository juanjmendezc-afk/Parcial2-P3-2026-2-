defmodule ValidacionIsla do
  @moduledoc """
  Validación previa con recursión del Problema 2: el mapa de la isla.

  Antes de buscar rutas, se verifica que el mapa sea válido:

  - todas las filas tienen el mismo número de posiciones (el de la primera fila);
  - todos los símbolos aparecen en `terrenos.csv`;
  - hay exactamente una posición inicial y exactamente un bote;
  - todo el borde del mapa es agua, es decir, la isla está cerrada.

  Se reportan **todos** los problemas encontrados, no solo el primero.

  Los símbolos no se escriben en el código: el inicio, el bote y el agua se
  reconocen por la columna `nombre` de `terrenos.csv` (`inicio`, `bote` y `agua`).
  Si alguien cambia, por ejemplo, la letra del bote en el archivo, la validación
  sigue funcionando.

  Todas las funciones son puras y recursivas. Por requisito del parcial no se
  usan los módulos `Enum` ni `Stream` (tampoco `length/1` ni `Enum.reverse/1`;
  contar e invertir son funciones recursivas propias). Se permite `Map`.

  Los terrenos se reciben como un mapa `%{simbolo => terreno}`, donde cada
  terreno es un mapa o struct con al menos el campo `nombre` (por ejemplo,
  `%Terreno{}`), así que este módulo no depende de dónde esté definido el struct.
  """

  @doc """
  Valida el mapa de la isla.

  - `filas`: lista de filas en orden (la primera es la fila 0); cada fila es una
    lista de símbolos, por ejemplo `[["~", "~", "~"], ["~", "P", "~"], ...]`.
  - `terrenos`: mapa `%{simbolo => terreno}` construido a partir de `terrenos.csv`.

  Devuelve `:ok` si el mapa es válido, o `{:error, problemas}` con una cadena por
  cada problema, lista para escribir en `validacion_isla.txt`.

  ## Ejemplo

      iex> ValidacionIsla.validar([["~", "C", "~"], ["~", "P", "~"], ["~", "~"]], terrenos)
      {:error, ["Fila 2: tiene 2 posiciones; se esperaban 3",
                "Posición {0,1}: el borde debe ser agua y contiene C",
                "No hay bote B"]}
  """
  def validar([], _terrenos), do: {:error, ["El mapa está vacío"]}

  def validar([primera | _] = filas, terrenos) do
    esperadas = contar(primera)
    ultima_fila = contar(filas) - 1

    # Recorre el mapa una sola vez y junta, por separado, cada tipo de hallazgo
    acumulado =
      revisar_filas(filas, 0, %{
        esperadas: esperadas,
        ultima_fila: ultima_fila,
        terrenos: terrenos,
        filas: [],
        simbolos: [],
        borde: [],
        inicios: [],
        botes: []
      })

    problemas =
      invertir(acumulado.filas) ++
        invertir(acumulado.simbolos) ++
        invertir(acumulado.borde) ++
        revisar_unico(invertir(acumulado.inicios), terrenos, "inicio") ++
        revisar_unico(invertir(acumulado.botes), terrenos, "bote")

    case problemas do
      [] -> :ok
      _ -> {:error, problemas}
    end
  end

  @doc """
  Devuelve las líneas que se escriben en `validacion_isla.txt`.

  Si el mapa es válido, devuelve una única línea que lo indica, para que el
  archivo de salida se cree igual en cada ejecución.
  """
  def lineas_reporte(:ok), do: ["El mapa es válido"]
  def lineas_reporte({:error, problemas}), do: problemas

  # ---------------------------------------------------------------------------
  # Recorrido recursivo: filas -> columnas
  # ---------------------------------------------------------------------------

  # Caso base: no quedan filas por revisar
  defp revisar_filas([], _fila, acumulado), do: acumulado

  # Caso recursivo: se revisa el tamaño de la fila y sus posiciones,
  # y se continúa con la fila siguiente
  defp revisar_filas([posiciones | resto], fila, acumulado) do
    tamano = contar(posiciones)

    acumulado =
      acumulado
      |> revisar_tamano(fila, tamano)
      |> revisar_columnas(posiciones, fila, 0, tamano)

    revisar_filas(resto, fila + 1, acumulado)
  end

  # Fila con el número esperado de posiciones: no hay nada que reportar
  defp revisar_tamano(%{esperadas: esperadas} = acumulado, _fila, esperadas), do: acumulado

  defp revisar_tamano(acumulado, fila, tamano) do
    problema = "Fila #{fila}: tiene #{tamano} posiciones; se esperaban #{acumulado.esperadas}"
    %{acumulado | filas: [problema | acumulado.filas]}
  end

  # Caso base: no quedan columnas en la fila
  defp revisar_columnas(acumulado, [], _fila, _columna, _tamano), do: acumulado

  # Caso recursivo: se revisa la posición {fila, columna} y se avanza a la siguiente
  defp revisar_columnas(acumulado, [simbolo | resto], fila, columna, tamano) do
    posicion = {fila, columna}

    acumulado
    |> revisar_simbolo(simbolo, posicion)
    |> revisar_borde(simbolo, posicion, tamano)
    |> registrar_especial(simbolo, posicion)
    |> revisar_columnas(resto, fila, columna + 1, tamano)
  end

  # ---------------------------------------------------------------------------
  # Revisiones de cada posición
  # ---------------------------------------------------------------------------

  # El símbolo debe existir en terrenos.csv
  defp revisar_simbolo(acumulado, simbolo, posicion) do
    if Map.has_key?(acumulado.terrenos, simbolo) do
      acumulado
    else
      problema = "Posición #{texto_posicion(posicion)}: el símbolo #{simbolo} no está en terrenos.csv"
      %{acumulado | simbolos: [problema | acumulado.simbolos]}
    end
  end

  # Si la posición está en el borde, su terreno debe ser agua
  defp revisar_borde(acumulado, simbolo, posicion, tamano) do
    if en_borde?(posicion, acumulado.ultima_fila, tamano) and not es?(acumulado.terrenos, simbolo, "agua") do
      problema = "Posición #{texto_posicion(posicion)}: el borde debe ser agua y contiene #{simbolo}"
      %{acumulado | borde: [problema | acumulado.borde]}
    else
      acumulado
    end
  end

  # Guarda dónde aparecen el inicio y el bote, para contarlos al final
  defp registrar_especial(acumulado, simbolo, posicion) do
    cond do
      es?(acumulado.terrenos, simbolo, "inicio") -> %{acumulado | inicios: [posicion | acumulado.inicios]}
      es?(acumulado.terrenos, simbolo, "bote") -> %{acumulado | botes: [posicion | acumulado.botes]}
      true -> acumulado
    end
  end

  # Una posición está en el borde si está en la primera o la última fila,
  # o en la primera o la última columna de su propia fila
  defp en_borde?({fila, columna}, ultima_fila, tamano) do
    fila == 0 or fila == ultima_fila or columna == 0 or columna == tamano - 1
  end

  # ---------------------------------------------------------------------------
  # Inicio y bote: deben aparecer exactamente una vez
  # ---------------------------------------------------------------------------

  # Exactamente una posición: correcto
  defp revisar_unico([_una], _terrenos, _nombre), do: []

  # Ninguna posición
  defp revisar_unico([], terrenos, nombre) do
    case simbolo_de(terrenos, nombre) do
      nil -> ["terrenos.csv no define un terreno con nombre #{nombre}"]
      simbolo -> ["No hay #{descripcion(nombre, 1)} #{simbolo}"]
    end
  end

  # Dos o más posiciones: se listan todas
  defp revisar_unico(posiciones, terrenos, nombre) do
    cantidad = contar(posiciones)
    simbolo = simbolo_de(terrenos, nombre)
    ["Hay #{cantidad} #{descripcion(nombre, cantidad)} #{simbolo}: #{texto_posiciones(posiciones)}"]
  end

  defp descripcion("inicio", 1), do: "posición inicial"
  defp descripcion("inicio", _), do: "posiciones iniciales"
  defp descripcion("bote", 1), do: "bote"
  defp descripcion("bote", _), do: "botes"

  # ---------------------------------------------------------------------------
  # Consultas sobre los terrenos (por nombre, no por símbolo)
  # ---------------------------------------------------------------------------

  # Indica si el símbolo corresponde al terreno con ese nombre
  defp es?(terrenos, simbolo, nombre) do
    case Map.get(terrenos, simbolo) do
      %{nombre: nombre_terreno} -> normalizar(nombre_terreno) == nombre
      nil -> false
    end
  end

  # Busca el símbolo cuyo terreno tiene el nombre dado; nil si no existe
  defp simbolo_de(terrenos, nombre), do: buscar_simbolo(Map.to_list(terrenos), nombre)

  defp buscar_simbolo([], _nombre), do: nil

  defp buscar_simbolo([{simbolo, %{nombre: nombre_terreno}} | resto], nombre) do
    if normalizar(nombre_terreno) == nombre, do: simbolo, else: buscar_simbolo(resto, nombre)
  end

  defp normalizar(texto), do: texto |> String.trim() |> String.downcase()

  # ---------------------------------------------------------------------------
  # Funciones auxiliares (recursivas, sin Enum)
  # ---------------------------------------------------------------------------

  # Cuenta los elementos de una lista con recursión de cola
  defp contar(lista), do: contar(lista, 0)

  defp contar([], total), do: total
  defp contar([_head | tail], total), do: contar(tail, total + 1)

  # Invierte una lista con recursión de cola
  defp invertir(lista), do: invertir(lista, [])

  defp invertir([], acumulado), do: acumulado
  defp invertir([head | tail], acumulado), do: invertir(tail, [head | acumulado])

  defp texto_posicion({fila, columna}), do: "{#{fila},#{columna}}"

  # Une posiciones en el formato del enunciado: "{1,1} y {4,3}" o "{1,1}, {2,2} y {4,3}"
  defp texto_posiciones([unica]), do: texto_posicion(unica)
  defp texto_posiciones([penultima, ultima]), do: texto_posicion(penultima) <> " y " <> texto_posicion(ultima)
  defp texto_posiciones([primera | resto]), do: texto_posicion(primera) <> ", " <> texto_posiciones(resto)
end

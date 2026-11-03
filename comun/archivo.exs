defmodule Archivo do
  @moduledoc """
  Módulo común de lectura y escritura de archivos para los problemas del Parcial 2.

  Es el único módulo con efectos secundarios sobre el disco. Los demás módulos
  reciben los datos ya leídos y devuelven las líneas que se deben escribir,
  sin tocar archivos directamente.

  Cumple los requisitos generales del parcial:
  - La lectura se hace con `File.stream!/1`, línea por línea y de forma perezosa.
  - Las líneas vacías y las que comienzan con `#` se ignoran.
  - Los números de línea empiezan en 1 y cuentan todas las líneas del archivo,
    incluidos los comentarios y las líneas vacías.
  - La escritura se hace línea por línea, sin construir un único string.
  - Si un archivo de entrada no existe, se devuelve un mensaje claro en lugar
    de terminar con una excepción.
  """

  # Marca de orden de bytes (BOM) que algunos editores de Windows agregan al
  # inicio de los archivos UTF-8. Si no se quita, la primera línea no se reconoce
  # como comentario y su primer campo llega con un carácter invisible.
  @bom "﻿"

  @doc """
  Abre un archivo de entrada para leerlo de forma perezosa.

  Devuelve `{:ok, stream}`, donde el stream produce tuplas `{numero_linea, texto}`
  con el texto ya recortado (sin espacios ni saltos de línea al inicio y al final,
  incluido el `\\r` de los archivos de Windows). Las líneas vacías y los
  comentarios no aparecen en el stream, pero sí cuentan para la numeración.

  Si la ruta no existe o es una carpeta, devuelve `{:error, mensaje}`.

  ## Ejemplo

      iex> {:ok, lineas} = Archivo.leer_lineas("conexiones.csv")
      iex> Enum.take(lineas, 2)
      [{2, "Armenia,Pereira,45"}, {3, "Pereira,Manizales,52"}]
  """
  def leer_lineas(ruta) do
    cond do
      File.dir?(ruta) ->
        {:error, "#{Path.basename(ruta)} es una carpeta, no un archivo (ruta: #{ruta})"}

      not File.exists?(ruta) ->
        {:error, "El archivo #{Path.basename(ruta)} no existe (ruta: #{ruta})"}

      true ->
        lineas =
          ruta
          |> File.stream!()                         # Lee el archivo línea por línea
          |> Stream.with_index(1)                   # Numera todas las líneas, desde 1
          |> Stream.map(&limpiar/1)                 # {numero, texto recortado}
          |> Stream.reject(&ignorar?/1)             # Descarta vacías y comentarios

        {:ok, lineas}
    end
  end

  @doc """
  Crea (o reemplaza) el archivo `ruta` y escribe en él cada elemento de `lineas`,
  una por línea. `lineas` puede ser una lista o un stream de cadenas; se escribe
  a medida que se recorre, sin unir todo en un único string.

  Si la carpeta de destino no existe, se crea. Devuelve `:ok` o `{:error, mensaje}`.

  ## Ejemplo

      iex> Archivo.escribir_lineas("salida.txt", ["Línea 1", "Línea 2"])
      :ok
  """
  def escribir_lineas(ruta, lineas) do
    with :ok <- preparar(ruta) do
      lineas
      |> Stream.map(fn linea -> [linea, "\n"] end)    # Cada elemento termina en salto de línea
      |> Enum.into(File.stream!(ruta, [:append]))     # Se escribe a medida que llega

      :ok
    end
  end

  @doc """
  Igual que `escribir_lineas/2`, pero además imprime cada línea en pantalla.

  Sirve cuando el enunciado pide la misma información en pantalla y en archivo:
  cada línea se muestra y se escribe en una sola pasada, sin recorrer los datos
  dos veces.

  ## Ejemplo

      iex> Archivo.emitir("rutas_encontradas.txt", ["=== Armenia -> Manizales ==="])
      === Armenia -> Manizales ===
      :ok
  """
  def emitir(ruta, lineas) do
    lineas
    |> Stream.each(&IO.puts/1)      # Efecto en pantalla, línea por línea
    |> then(&escribir_lineas(ruta, &1))
  end

  # ---------------------------------------------------------------------------
  # Funciones privadas
  # ---------------------------------------------------------------------------

  # Recorta el texto y, en la primera línea, quita la marca BOM si la tiene
  defp limpiar({linea, 1}), do: {1, linea |> String.trim() |> String.trim_leading(@bom) |> String.trim()}
  defp limpiar({linea, numero}), do: {numero, String.trim(linea)}

  # Una línea se ignora si quedó vacía o si es un comentario
  defp ignorar?({_numero, ""}), do: true
  defp ignorar?({_numero, texto}), do: String.starts_with?(texto, "#")

  # Crea la carpeta de destino si falta y deja el archivo vacío.
  # File.write/2 crea el archivo o lo reemplaza; si no se puede escribir
  # (por ejemplo, porque está abierto en otro programa), devuelve el error
  # como tupla en lugar de lanzar una excepción.
  defp preparar(ruta) do
    with :ok <- File.mkdir_p(Path.dirname(ruta)),
         :ok <- File.write(ruta, "") do
      :ok
    else
      {:error, razon} -> {:error, "No se pudo escribir #{Path.basename(ruta)}: #{:file.format_error(razon)}"}
    end
  end
end

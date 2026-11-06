defmodule Conexion do
  defstruct [:origen, :destino, :distancia]

  def parse(linea) do
    case linea |> String.split(",") |> Enum.map(&String.trim/1) do
      ["", _, _] ->
        {:error, "Falta la ciudad de origen"}

      [_, "", _] ->
        {:error, "Falta la ciudad de destino"}

      [_, _, ""] ->
        {:error, "Falta la distancia"}

      [origen, destino, distancia_texto] ->
        case Integer.parse(distancia_texto) do
          {distancia, ""} when distancia >= 0  ->
            {:ok, %Conexion{origen: origen, destino: destino, distancia: distancia}}

          _ ->
            {:error, "La distancia debe ser un entero no negativo"}
        end

      _ ->
        {:error, "Se esperaban tres campos: origen,destino,distancia"}
    end
  end
end

defmodule Ruta do
  defstruct [:ciudades, :distancia]
end

defmodule RutasCiudades do
  @archivo_conexiones "conexiones.csv"
  @archivo_consultas "consultas.txt"
  @archivo_errores "errores_conexiones.txt"
  @archivo_depuracion "depuracion_conexiones.txt"
  @archivo_alcance "alcance.txt"
  @archivo_salida "rutas_encontradas.txt"

  def main do #1
    faltantes = Enum.reject([@archivo_conexiones, @archivo_consultas], &File.regular?/1)

    case faltantes do
      [] ->
        Enum.each(
          [@archivo_errores, @archivo_depuracion, @archivo_alcance, @archivo_salida],
          &File.write!(&1, "")
        )

        grafo =
          @archivo_conexiones
          |> cargar_conexiones_lazy()
          |> depurar_conexiones_recursivo(%{})
          |> construir_grafo()

        procesar_consultas_lazy(@archivo_consultas, grafo)

      archivos ->
        Enum.each(archivos, &IO.puts("Error: falta el archivo de entrada #{&1}."))
    end
  end


  defp lineas_utiles(path) do #3
    path
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {linea, numero} ->
      {String.trim(linea), numero}
    end)
    |> Stream.reject(fn {linea, _numero} ->
      linea == "" or String.starts_with?(linea, "#")
    end)
  end

  defp cargar_conexiones_lazy(path) do
    path
    |> lineas_utiles()
    |> Stream.flat_map(fn {linea, numero} ->
      case Conexion.parse(linea) do
        {:ok, conexion} ->
          [{numero, linea, conexion}]

        {:error, motivo} ->
          File.write!(@archivo_errores, "Línea #{numero}: #{linea} -> #{motivo}\n", [:append])
          []
      end
    end)
    |> Enum.to_list()
  end


  defp depurar_conexiones_recursivo([], _primeras), do: []

  defp depurar_conexiones_recursivo([{linea, contenido, conexion} | resto], primeras) do
    %Conexion{origen: origen, destino: destino, distancia: distancia} = conexion
    par = {min(origen, destino), max(origen, destino)}
    prefijo = "Línea #{linea}: #{contenido} -> "

    case {origen == destino, Map.fetch(primeras, par)} do
      {true, _} ->
        File.write!(
          @archivo_depuracion,
          prefijo <> "conecta una ciudad consigo misma; se descarta\n",
          [:append]
        )

        depurar_conexiones_recursivo(resto, primeras)

      {false, :error} ->
        nuevas_primeras = Map.put(primeras, par, {linea, distancia})
        [conexion | depurar_conexiones_recursivo(resto, nuevas_primeras)]

      {false, {:ok, {linea_original, ^distancia}}} ->
        File.write!(
          @archivo_depuracion,
          prefijo <> "repetida (línea #{linea_original}); se descarta\n",
          [:append]
        )

        depurar_conexiones_recursivo(resto, primeras)

      {false, {:ok, {linea_original, distancia_original}}} ->
        File.write!(
          @archivo_depuracion,
          prefijo <>
            "distancia distinta a la de la línea #{linea_original} (#{distancia_original}); " <>
            "se conserva la de la línea #{linea_original}\n",
          [:append]
        )

        depurar_conexiones_recursivo(resto, primeras)
    end
  end

  defp construir_grafo(conexiones) do
    conexiones
    |> Enum.reduce(%{}, fn %Conexion{origen: a, destino: b, distancia: d}, grafo ->
      grafo
      |> Map.update(a, [{b, d}], &[{b, d} | &1])
      |> Map.update(b, [{a, d}], &[{a, d} | &1])
    end)
    |> Map.new(fn {ciudad, vecinos} ->
      {ciudad, Enum.reverse(vecinos)}
    end)
  end

  defp stream_alcanzables(origen, grafo) do
    Stream.iterate(MapSet.new([origen]), fn ciudades_actuales ->
      Enum.reduce(ciudades_actuales, ciudades_actuales, fn ciudad, acumulado ->
        Enum.reduce(Map.get(grafo, ciudad, []), acumulado, fn {vecino, _distancia}, alcance ->
          MapSet.put(alcance, vecino)
        end)
      end)
    end)
  end

  # Consume pares consecutivos y se detiene al calcular el primer conjunto repetido.
  defp calcular_alcance_hasta_estabilizar(origen, grafo) do
    origen
    |> stream_alcanzables(grafo)
    |> Stream.chunk_every(2, 1)
    |> Stream.with_index(0)
    |> Enum.reduce_while(MapSet.new([origen]), fn {[actual, siguiente], paso}, _anterior ->
      ciudades = actual |> Enum.sort() |> Enum.join(", ")
      File.write!(@archivo_alcance, "Paso #{paso}: #{ciudades}\n", [:append])

      if actual == siguiente do
        File.write!(@archivo_alcance, "Se estabiliza en el paso #{paso}\n", [:append])
        {:halt, actual}
      else
        {:cont, siguiente}
      end
    end)
  end

  defp procesar_consultas_lazy(path, grafo) do
    path
    |> lineas_utiles()
    |> Stream.each(fn {linea, numero} ->
      case linea |> String.split(",") |> Enum.map(&String.trim/1) do
        [origen, destino] when origen != "" and destino != "" ->
          resolver_consulta(origen, destino, grafo)

        _ ->
          escribir_resultado("Consulta inválida en la línea #{numero}: #{linea}")
      end
    end)
    |> Stream.run()
  end

  defp resolver_consulta(origen, destino, grafo) do
    escribir_resultado("=== #{origen} -> #{destino} ===")
    File.write!(@archivo_alcance, "=== Alcance desde #{origen} ===\n", [:append])

    if Map.has_key?(grafo, origen) and Map.has_key?(grafo, destino) do
      alcanzables = calcular_alcance_hasta_estabilizar(origen, grafo)

      if MapSet.member?(alcanzables, destino) do
        rutas = buscar_rutas_recursivo(origen, destino, grafo, [origen], 0)
        escribir_resultado_rutas(rutas)
      else
        escribir_resultado("Sin rutas posibles entre origen y destino.")
        escribir_resultado("Número de rutas: 0")
      end
    else
      mensaje = "Ciudad de origen o destino desconocida en la consulta."
      File.write!(@archivo_alcance, mensaje <> "\n", [:append])
      escribir_resultado(mensaje)
    end

    File.write!(@archivo_alcance, "\n", [:append])
    escribir_resultado("")
  end

  defp buscar_rutas_recursivo(actual, destino, _grafo, camino, distancia) when actual == destino do
    [%Ruta{ciudades: Enum.reverse(camino), distancia: distancia}]
  end

  defp buscar_rutas_recursivo(actual, destino, grafo, camino, distancia) do
    grafo
    |> Map.get(actual, [])
    |> Enum.flat_map(fn {vecino, tramo} ->
      if vecino in camino do
        []
      else
        buscar_rutas_recursivo(vecino, destino, grafo, [vecino | camino], distancia + tramo)
      end
    end)
  end

  defp escribir_resultado_rutas(rutas) do
    rutas
    |> Enum.with_index(1)
    |> Enum.each(fn {%Ruta{ciudades: ciudades, distancia: distancia}, numero} ->
      recorrido = Enum.join(ciudades, " -> ")
      escribir_resultado("Ruta #{numero}: #{recorrido} (#{length(ciudades)} ciudades, #{distancia} km)")
    end)

    escribir_resultado("Número de rutas: #{length(rutas)}")

    menos_ciudades = rutas |> Enum.map(&length(&1.ciudades)) |> Enum.min()
    menor_distancia = rutas |> Enum.map(& &1.distancia) |> Enum.min()

    rutas
    |> Enum.filter(&(length(&1.ciudades) == menos_ciudades))
    |> Enum.each(fn ruta ->
      escribir_resultado("Ruta más corta: #{Enum.join(ruta.ciudades, " -> ")}")
    end)

    rutas
    |> Enum.filter(&(&1.distancia == menor_distancia))
    |> Enum.each(fn ruta ->
      escribir_resultado(
        "Ruta de menor distancia: #{Enum.join(ruta.ciudades, " -> ")} (#{ruta.distancia} km)"
      )
    end)
  end

  defp escribir_resultado(linea) do
    IO.puts(linea)
    File.write!(@archivo_salida, linea <> "\n", [:append])
  end
end

RutasCiudades.main()

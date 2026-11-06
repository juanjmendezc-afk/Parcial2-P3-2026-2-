# Parcial 2 - Problema 2: Escapar de la isla
#
# Uso:  elixir isla.exs [isla.txt] [terrenos.csv]
# (si no se indican archivos, usa los que están junto a este programa)
#
# Ningún símbolo ni costo está escrito en el código: todo sale de terrenos.csv.
# El inicio, el bote y el agua se reconocen por la columna "nombre".

Code.require_file("../comun/archivo.exs", __DIR__)
Code.require_file("validacion_isla.exs", __DIR__)

# -----------------------------------------------------------------------------
# Structs
# -----------------------------------------------------------------------------

defmodule Terreno do
  @moduledoc "Un tipo de terreno definido en terrenos.csv."
  defstruct [:simbolo, :nombre, :transitable, :costo]

  @doc "Convierte `simbolo,nombre,transitable,costo` en `{:ok, %Terreno{}}` o `{:error, motivo}`."
  def parse(linea) do
    case linea |> String.split(",") |> Enum.map(&String.trim/1) do
      [simbolo, nombre, transitable, costo] when simbolo != "" and nombre != "" ->
        with {:ok, transitable?} <- convertir_transitable(transitable),
             {:ok, costo} <- convertir_costo(costo) do
          {:ok, %Terreno{simbolo: simbolo, nombre: nombre, transitable: transitable?, costo: costo}}
        end

      campos when length(campos) < 4 ->
        {:error, "campos faltantes"}

      [_, _, _, _] ->
        {:error, "campos faltantes"}

      _ ->
        {:error, "campos de más (se esperaban 4)"}
    end
  end

  defp convertir_transitable(texto) do
    case texto |> String.downcase() do
      t when t in ["si", "sí"] -> {:ok, true}
      "no" -> {:ok, false}
      _ -> {:error, "transitable debe ser si o no"}
    end
  end

  defp convertir_costo(texto) do
    case Integer.parse(texto) do
      {costo, ""} when costo >= 0 -> {:ok, costo}
      _ -> {:error, "costo no numérico"}
    end
  end

  def nombre?(%Terreno{nombre: nombre}, buscado), do: nombre |> String.trim() |> String.downcase() == buscado
end

defmodule Ruta do
  @moduledoc "Una ruta: las posiciones {fila, columna} en orden y su costo total."
  defstruct posiciones: [], costo: 0

  # Los movimientos se calculan a partir de las posiciones: una menos que ellas
  def movimientos(%Ruta{posiciones: posiciones}), do: length(posiciones) - 1

  def texto_posicion({fila, columna}), do: "{#{fila},#{columna}}"

  def recorrido(%Ruta{posiciones: posiciones}) do
    posiciones |> Enum.map(&texto_posicion/1) |> Enum.join(" -> ")
  end

  def lineas_pantalla(%Ruta{} = ruta, numero) do
    [
      "Ruta #{numero}:",
      recorrido(ruta),
      "Número de movimientos: #{movimientos(ruta)}",
      "Costo: #{ruta.costo}"
    ]
  end

  def linea_csv(%Ruta{} = ruta, numero) do
    "#{numero};#{movimientos(ruta)};#{ruta.costo};#{recorrido(ruta)}"
  end
end

# -----------------------------------------------------------------------------
# Mapa y búsqueda recursiva
# -----------------------------------------------------------------------------

defmodule Mapa do
  @doc "Convierte las filas de símbolos en un mapa %{ {fila, columna} => %Terreno{} }."
  def construir(filas, terrenos) do
    for {fila, f} <- Enum.with_index(filas),
        {simbolo, c} <- Enum.with_index(fila),
        into: %{},
        do: {{f, c}, Map.fetch!(terrenos, simbolo)}
  end

  @doc "Posición del terreno con ese nombre (inicio, bote...)."
  def posicion_de(mapa, nombre) do
    Enum.find_value(mapa, fn {posicion, terreno} -> if Terreno.nombre?(terreno, nombre), do: posicion end)
  end
end

defmodule Busqueda do
  # Orden en que se prueban las 4 direcciones: abajo, derecha, arriba, izquierda
  # (el enunciado no fija un orden; este reproduce la "Ruta 1" del ejemplo)
  @movimientos [{1, 0}, {0, 1}, {-1, 0}, {0, -1}]

  @doc "Todas las rutas de `inicio` a `bote` sin repetir posiciones."
  def rutas(mapa, inicio, bote) do
    explorar(mapa, inicio, bote, [inicio], MapSet.new([inicio]), 0)
  end

  # Caso base: se llegó al bote -> una ruta completa
  defp explorar(_mapa, bote, bote, camino, _visitadas, costo) do
    [%Ruta{posiciones: Enum.reverse(camino), costo: costo}]
  end

  # Caso recursivo: probar las 4 direcciones
  defp explorar(mapa, {fila, columna}, bote, camino, visitadas, costo) do
    Enum.flat_map(@movimientos, fn {df, dc} ->
      siguiente = {fila + df, columna + dc}

      case Map.get(mapa, siguiente) do
        # Fuera del mapa
        nil ->
          []

        # Pattern matching sobre el struct: las posiciones no transitables se descartan
        %Terreno{transitable: false} ->
          []

        # Transitable: se entra solo si no se ha visitado en esta ruta
        %Terreno{costo: costo_terreno} ->
          if MapSet.member?(visitadas, siguiente) do
            []
          else
            explorar(mapa, siguiente, bote, [siguiente | camino], MapSet.put(visitadas, siguiente), costo + costo_terreno)
          end
      end
    end)
  end
end

# -----------------------------------------------------------------------------
# Programa principal
# -----------------------------------------------------------------------------

defmodule Isla do
  def main(args) do
    ruta_isla = Enum.at(args, 0) || Path.join(__DIR__, "isla.txt")
    ruta_terrenos = Enum.at(args, 1) || Path.join(__DIR__, "terrenos.csv")

    with {:ok, lineas_isla} <- Archivo.leer_lineas(ruta_isla),
         {:ok, lineas_terrenos} <- Archivo.leer_lineas(ruta_terrenos),
         {:ok, terrenos} <- leer_terrenos(lineas_terrenos) do
      filas = Enum.map(lineas_isla, fn {_numero, texto} -> String.split(texto, " ", trim: true) end)

      # Validación previa (recursiva): siempre se escribe validacion_isla.txt
      validacion = ValidacionIsla.validar(filas, terrenos)
      :ok = Archivo.emitir(salida("validacion_isla.txt"), ValidacionIsla.lineas_reporte(validacion))

      case validacion do
        :ok -> resolver(filas, terrenos)
        {:error, _problemas} -> IO.puts("El mapa no es válido: no se realiza la búsqueda.")
      end
    else
      {:error, mensaje} -> IO.puts("Error: " <> mensaje)
    end
  end

  defp salida(nombre), do: Path.join(__DIR__, nombre)

  # terrenos.csv -> %{simbolo => %Terreno{}} (conversión perezosa, mapa al final)
  defp leer_terrenos(lineas) do
    {buenas, malas} =
      lineas
      |> Stream.map(fn {numero, texto} -> {numero, texto, Terreno.parse(texto)} end)
      |> Enum.split_with(fn {_n, _t, resultado} -> match?({:ok, _}, resultado) end)

    case malas do
      [] ->
        {:ok, Map.new(buenas, fn {_n, _t, {:ok, terreno}} -> {terreno.simbolo, terreno} end)}

      _ ->
        detalle = Enum.map_join(malas, "; ", fn {n, t, {:error, m}} -> "línea #{n} (#{t}): #{m}" end)
        {:error, "terrenos.csv tiene líneas inválidas: " <> detalle}
    end
  end

  defp resolver(filas, terrenos) do
    mapa = Mapa.construir(filas, terrenos)
    inicio = Mapa.posicion_de(mapa, "inicio")
    bote = Mapa.posicion_de(mapa, "bote")
    rutas = Busqueda.rutas(mapa, inicio, bote)
    numeradas = Enum.with_index(rutas, 1)

    # Pantalla: cada ruta
    numeradas |> Enum.flat_map(fn {ruta, n} -> Ruta.lineas_pantalla(ruta, n) ++ [""] end) |> Enum.each(&IO.puts/1)

    # rutas_isla.csv: una línea por ruta
    cabecera = ["ruta;movimientos;costo;recorrido"]
    csv = Stream.concat(cabecera, Stream.map(numeradas, fn {ruta, n} -> Ruta.linea_csv(ruta, n) end))
    :ok = Archivo.escribir_lineas(salida("rutas_isla.csv"), csv)

    # resumen_isla.txt (y pantalla): totales, ruta más corta, de menor costo y mapa
    :ok = Archivo.emitir(salida("resumen_isla.txt"), lineas_resumen(numeradas, filas))
  end

  defp lineas_resumen([], filas) do
    ["Número total de rutas: 0", "No hay ninguna ruta del inicio al bote", ""] ++ lineas_mapa(filas, [])
  end

  defp lineas_resumen(numeradas, filas) do
    menos_mov = numeradas |> Enum.map(fn {r, _} -> Ruta.movimientos(r) end) |> Enum.min()
    menor_costo = numeradas |> Enum.map(fn {r, _} -> r.costo end) |> Enum.min()

    cortas = Enum.filter(numeradas, fn {r, _} -> Ruta.movimientos(r) == menos_mov end)
    baratas = Enum.filter(numeradas, fn {r, _} -> r.costo == menor_costo end)
    {mejor, _n} = hd(baratas)

    ["Número total de rutas: #{length(numeradas)}"] ++
      Enum.flat_map(cortas, fn {r, n} ->
        ["Ruta más corta: #{Ruta.movimientos(r)} movimientos", "  Ruta #{n}: #{Ruta.recorrido(r)}"]
      end) ++
      Enum.flat_map(baratas, fn {r, n} ->
        ["Ruta de menor costo: costo #{r.costo} (#{Ruta.movimientos(r)} movimientos)", "  Ruta #{n}: #{Ruta.recorrido(r)}"]
      end) ++
      ["", "Mapa con la ruta de menor costo marcada con *:"] ++ lineas_mapa(filas, mejor.posiciones)
  end

  # El mapa en el mismo formato de isla.txt, con * en las posiciones de la ruta
  defp lineas_mapa(filas, posiciones) do
    marcadas = MapSet.new(posiciones)

    filas
    |> Enum.with_index()
    |> Enum.map(fn {fila, f} ->
      fila
      |> Enum.with_index()
      |> Enum.map(fn {simbolo, c} -> if MapSet.member?(marcadas, {f, c}), do: "*", else: simbolo end)
      |> Enum.join(" ")
    end)
  end
end

Isla.main(System.argv())

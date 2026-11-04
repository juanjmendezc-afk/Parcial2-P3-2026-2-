# Pruebas de las validaciones con recursión (rol transversal).
#
# Ejecuta Depuracion.depurar/1 y ValidacionIsla.validar/2 sobre los casos de
# esta carpeta y escribe las salidas en ./salidas, para incluirlas en la sección
# "Datos y resultados" del PDF.
#
# Uso:  elixir probar_validaciones.exs
#
# Nota: la lectura de conexiones y terrenos de este archivo es una versión
# mínima, solo para probar las validaciones de forma aislada. La lectura
# oficial (Conexion.parse/1, carga de terrenos e isla) es de cada problema.

Code.require_file("../../comun/archivo.exs", __DIR__)
Code.require_file("../../problema1_rutas/depuracion.exs", __DIR__)
Code.require_file("../../problema2_isla/validacion_isla.exs", __DIR__)

defmodule ProbarValidaciones do
  @casos __DIR__
  @salidas Path.join(__DIR__, "salidas")

  def main do
    probar_depuracion("conexiones_enunciado.csv", "depuracion_conexiones_enunciado.txt")
    probar_depuracion("conexiones_pequeno.csv", "depuracion_conexiones_pequeno.txt")

    with {:ok, terrenos} <- leer_terrenos("terrenos.csv") do
      probar_isla("isla_enunciado.txt", terrenos, "validacion_isla_enunciado.txt")
      probar_isla("isla_errores_enunciado.txt", terrenos, "validacion_isla_errores_enunciado.txt")
      probar_isla("isla_pequena_valida.txt", terrenos, "validacion_isla_pequena_valida.txt")
      probar_isla("isla_pequena_invalida.txt", terrenos, "validacion_isla_pequena_invalida.txt")
    else
      {:error, mensaje} -> IO.puts(:standard_error, mensaje)
    end
  end

  # --- Problema 1 -------------------------------------------------------------

  defp probar_depuracion(entrada, salida) do
    IO.puts("\n=== Depuración: #{entrada} -> salidas/#{salida} ===")

    case Archivo.leer_lineas(Path.join(@casos, entrada)) do
      {:ok, lineas} ->
        {_conservadas, reportes} =
          lineas
          |> Stream.map(&conexion_numerada/1)
          |> Enum.to_list()
          |> Depuracion.depurar()

        Archivo.emitir(Path.join(@salidas, salida), Depuracion.lineas_reporte(reportes))

      {:error, mensaje} ->
        IO.puts(:standard_error, mensaje)
    end
  end

  defp conexion_numerada({linea, texto}) do
    [origen, destino, distancia] = String.split(texto, ",")
    {linea, texto, %{origen: origen, destino: destino, distancia: String.to_integer(distancia)}}
  end

  # --- Problema 2 -------------------------------------------------------------

  defp probar_isla(entrada, terrenos, salida) do
    IO.puts("\n=== Validación de la isla: #{entrada} -> salidas/#{salida} ===")

    case Archivo.leer_lineas(Path.join(@casos, entrada)) do
      {:ok, lineas} ->
        filas = lineas |> Stream.map(fn {_linea, texto} -> String.split(texto) end) |> Enum.to_list()
        resultado = ValidacionIsla.validar(filas, terrenos)
        Archivo.emitir(Path.join(@salidas, salida), ValidacionIsla.lineas_reporte(resultado))

      {:error, mensaje} ->
        IO.puts(:standard_error, mensaje)
    end
  end

  defp leer_terrenos(entrada) do
    with {:ok, lineas} <- Archivo.leer_lineas(Path.join(@casos, entrada)) do
      terrenos =
        lineas
        |> Stream.map(fn {_linea, texto} ->
          [simbolo, nombre, transitable, costo] = String.split(texto, ",")
          {simbolo, %{simbolo: simbolo, nombre: nombre, transitable: transitable == "si", costo: String.to_integer(costo)}}
        end)
        |> Map.new()

      {:ok, terrenos}
    end
  end
end

ProbarValidaciones.main()

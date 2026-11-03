defmodule Depuracion do
  @moduledoc """
  Validación previa con recursión del Problema 1: depurar las conexiones.

  Después de leer las conexiones y antes de construir el grafo, se revisa la
  lista y se corrige:

  - una conexión de una ciudad consigo misma se descarta;
  - una conexión que ya apareció antes, en el mismo sentido o en el contrario,
    se descarta;
  - si un mismo par de ciudades aparece con distancias distintas, se conserva
    la primera que aparece en el archivo.

  Todas las funciones son puras y recursivas. Por requisito del parcial no se
  usan los módulos `Enum` ni `Stream` (tampoco `Enum.reverse/1`; la inversión
  de listas es una función recursiva propia). Para recordar los pares ya vistos
  se usa un mapa.

  Las conexiones se reciben como mapas o structs con los campos `origen`,
  `destino` y `distancia` (por ejemplo, `%Conexion{}`), por lo que este módulo
  no depende de dónde esté definido el struct.
  """

  @doc """
  Depura una lista de conexiones numeradas.

  Recibe una lista de tuplas `{numero_linea, texto, conexion}`, en el orden del
  archivo, donde `texto` es la línea tal como se leyó y `conexion` tiene los
  campos `origen`, `destino` y `distancia`.

  Devuelve `{conservadas, reportes}`:

  - `conservadas`: las tuplas que pasan la depuración, en el mismo orden del archivo.
  - `reportes`: una cadena por cada corrección, lista para escribir en
    `depuracion_conexiones.txt`.

  ## Ejemplo

      iex> Depuracion.depurar([
      ...>   {2, "Armenia,Pereira,45", %{origen: "Armenia", destino: "Pereira", distancia: 45}},
      ...>   {6, "Pereira,Armenia,45", %{origen: "Pereira", destino: "Armenia", distancia: 45}}
      ...> ])
      {[{2, "Armenia,Pereira,45", %{origen: "Armenia", destino: "Pereira", distancia: 45}}],
       ["Línea 6: Pereira,Armenia,45 -> repetida (línea 2); se descarta"]}
  """
  def depurar(conexiones), do: depurar(conexiones, %{}, [], [])

  # Caso base: no quedan conexiones por revisar.
  # Los acumuladores se construyeron agregando al inicio, así que se invierten
  # una sola vez para recuperar el orden del archivo.
  defp depurar([], _vistas, conservadas, reportes) do
    {invertir(conservadas), invertir(reportes)}
  end

  # Caso 1: la ciudad de origen y la de destino son la misma.
  # El patrón usa la variable `ciudad` dos veces, así que solo coincide cuando
  # ambos campos tienen el mismo valor.
  defp depurar([{linea, texto, %{origen: ciudad, destino: ciudad}} | resto], vistas, conservadas, reportes) do
    reporte = "Línea #{linea}: #{texto} -> conecta una ciudad consigo misma; se descarta"
    depurar(resto, vistas, conservadas, [reporte | reportes])
  end

  # Casos 2, 3 y 4: se busca si el par de ciudades ya apareció antes,
  # sin importar el sentido en que esté escrito.
  defp depurar([{linea, texto, %{origen: origen, destino: destino, distancia: km}} = actual | resto], vistas, conservadas, reportes) do
    par = clave_par(origen, destino)

    case Map.get(vistas, par) do
      # Caso 4: primera vez que aparece el par. Se conserva y se recuerda
      # en qué línea apareció y con qué distancia.
      nil ->
        depurar(resto, Map.put(vistas, par, {linea, km}), [actual | conservadas], reportes)

      # Caso 2: ya apareció con la misma distancia (el pin ^km exige que sea igual).
      {primera_linea, ^km} ->
        reporte = "Línea #{linea}: #{texto} -> repetida (línea #{primera_linea}); se descarta"
        depurar(resto, vistas, conservadas, [reporte | reportes])

      # Caso 3: ya apareció con otra distancia. Se conserva la primera.
      {primera_linea, km_original} ->
        reporte =
          "Línea #{linea}: #{texto} -> distancia distinta a la de la línea #{primera_linea} " <>
            "(#{km_original}); se conserva la de la línea #{primera_linea}"

        depurar(resto, vistas, conservadas, [reporte | reportes])
    end
  end

  @doc """
  Devuelve las líneas que se escriben en `depuracion_conexiones.txt`.

  Si no hubo correcciones, devuelve una única línea que lo indica, para que el
  archivo de salida se cree igual en cada ejecución.
  """
  def lineas_reporte([]), do: ["No se encontraron conexiones para depurar"]
  def lineas_reporte(reportes), do: reportes

  # ---------------------------------------------------------------------------
  # Funciones auxiliares (recursivas, sin Enum)
  # ---------------------------------------------------------------------------

  # Clave del par de ciudades sin importar el sentido: siempre se guarda
  # primero la ciudad que va antes en orden alfabético. Así, Armenia-Pereira
  # y Pereira-Armenia producen la misma clave {"Armenia", "Pereira"}.
  defp clave_par(a, b) when a <= b, do: {a, b}
  defp clave_par(a, b), do: {b, a}

  # Invierte una lista con recursión de cola, igual que en la guía de recursividad.
  defp invertir(lista), do: invertir(lista, [])

  defp invertir([], acumulado), do: acumulado
  defp invertir([head | tail], acumulado), do: invertir(tail, [head | acumulado])
end

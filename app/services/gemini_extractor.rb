class GeminiExtractor
  GEMINI_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent"

  def initialize(boleta)
    @boleta = boleta
  end

  def call
  contenido = preparar_contenido
  respuesta = llamar_api(contenido)
  parsear_respuesta(respuesta)
rescue => e
  Rails.logger.error "GeminiExtractor error: #{e.class} - #{e.message}"
  Rails.logger.error e.backtrace.first(5).join("\n")
  { error: e.message }
end

  private

  def preparar_contenido
    archivo = @boleta.archivo
    tipo = archivo.content_type

    if tipo == "application/pdf"
      texto = extraer_texto_pdf(archivo)
      if texto.strip.length > 100
        { tipo: :texto, contenido: texto }
      else
        { tipo: :binario, contenido: Base64.strict_encode64(archivo.download), mime: tipo }
      end
    elsif tipo.start_with?("image/")
      { tipo: :binario, contenido: Base64.strict_encode64(archivo.download), mime: tipo }
    else
      raise "Tipo de archivo no soportado: #{tipo}"
    end
  end

  def extraer_texto_pdf(archivo)
    require "pdf-reader"
    texto = ""
    archivo.open do |file|
      reader = PDF::Reader.new(file.path)
      reader.pages.each { |page| texto += page.text }
    end
    texto
  rescue
    ""
  end

  def llamar_api(contenido)
    partes = [{ text: prompt_extraccion }]

    if contenido[:tipo] == :binario
      partes << {
        inline_data: {
          mime_type: contenido[:mime],
          data: contenido[:contenido]
        }
      }
    else
      partes[0][:text] += "\n\nTexto de la boleta:\n#{contenido[:contenido]}"
    end

    conn = Faraday.new do |f|
      f.request :json
      f.response :json
      f.adapter Faraday.default_adapter
    end

    respuesta = conn.post("#{GEMINI_URL}?key=#{ENV['GEMINI_API_KEY']}") do |req|
      req.body = { contents: [{ parts: partes }] }
    end

    respuesta.body
  end

  def parsear_respuesta(respuesta)
  texto = respuesta.dig("candidates", 0, "content", "parts", 0, "text")
  return { error: "Sin respuesta de Gemini" } unless texto

  # Remover bloques de código markdown si existen
  texto_limpio = texto.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip

  # Buscar el JSON completo (desde el primer { hasta el último })
  inicio = texto_limpio.index("{")
  fin = texto_limpio.rindex("}")
  return { error: "No se encontró JSON en la respuesta" } unless inicio && fin

  json_str = texto_limpio[inicio..fin]
  datos = JSON.parse(json_str, symbolize_names: true)

  # Normalizar los campos que necesitamos
  {
    nombre_comercio: datos.dig(:comercio, :nombre) || datos[:nombre_comercio],
    rut_comercio:    datos.dig(:comercio, :rut)    || datos[:rut_comercio],
    fecha:           normalizar_fecha(datos.dig(:documento, :fecha) || datos[:fecha]),
    monto_total:     normalizar_monto(datos.dig(:totales, :total)   || datos[:monto_total])
  }
rescue JSON::ParserError => e
  { error: "Error al parsear JSON: #{e.message}" }
end

def normalizar_fecha(fecha_str)
  return nil unless fecha_str
  partes = fecha_str.to_s.split(/[-\/]/)
  return fecha_str if partes.length != 3
  # Si viene DD-MM-YYYY lo convertimos a YYYY-MM-DD
  if partes[0].length == 2
    "#{partes[2]}-#{partes[1]}-#{partes[0]}"
  else
    fecha_str
  end
rescue
  nil
end

def normalizar_monto(monto_str)
  return nil unless monto_str
  return monto_str.to_f if monto_str.is_a?(Numeric)
  # Eliminar solo $ y espacios, convertir coma decimal a punto
  monto_str.to_s.gsub("$", "").gsub(/\s/, "").gsub(",", ".").to_f
rescue
  nil
end

  def prompt_extraccion
    <<~PROMPT
      Eres un asistente especializado en extraer información de boletas chilenas.
      Analiza la boleta y extrae los siguientes datos en formato JSON estricto:

      {
        "nombre_comercio": "nombre del negocio o tienda",
        "rut_comercio": "RUT en formato XX.XXX.XXX-X",
        "fecha": "YYYY-MM-DD",
        "monto_total": 0000.00
      }

      Reglas:
      - Si un dato no aparece claramente, usa null
      - El monto_total debe ser un número decimal sin puntos de miles ni símbolo $
      - La fecha debe estar en formato YYYY-MM-DD
      - Responde ÚNICAMENTE con el JSON, sin explicaciones adicionales
    PROMPT
  end
end
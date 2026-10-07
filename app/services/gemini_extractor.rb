require "faraday"
require "base64"
require "json"
require "date"

# Extrae los datos de una boleta chilena (PDF o imagen) usando Gemini.
#
# - PDF con texto: se extrae el texto con pdf-reader y se envía solo el texto (más rápido y barato).
# - Imagen o PDF escaneado: se envía el archivo y Gemini hace el OCR con su modelo de visión.
class GeminiExtractor
  MODEL   = ENV.fetch("GEMINI_MODEL", "gemini-2.5-flash")
  API_URL = "https://generativelanguage.googleapis.com/v1beta/models/#{MODEL}:generateContent"

  MIN_TEXTO_PDF = 50      # menos que esto: se asume PDF escaneado y se envía como imagen
  MAX_TEXTO_PDF = 12_000  # suficiente para boletas largas sin perder el total, que va al final

  FORMATOS_FECHA = [ "%Y-%m-%d", "%d/%m/%Y", "%d-%m-%Y" ].freeze

  PROMPT = <<~PROMPT.strip
    Eres un extractor de datos de boletas y facturas chilenas. Lee el documento y devuelve un JSON con estos campos:
    - nombre_comercio: razón social o nombre de fantasía del emisor.
    - rut_comercio: RUT del emisor con formato XX.XXX.XXX-X.
    - fecha: fecha de emisión en formato YYYY-MM-DD (las boletas chilenas la escriben como DD/MM/AAAA).
    - monto_total: total final pagado en pesos chilenos, como número entero sin puntos ni símbolos.
    - items: lista con la descripción de cada producto o servicio comprado.
    Si un dato no aparece o no se puede leer, usa null. No inventes datos.
  PROMPT

  # Esquema de salida: Gemini queda obligado a responder con este JSON.
  RESPONSE_SCHEMA = {
    type: "OBJECT",
    properties: {
      nombre_comercio: { type: "STRING", nullable: true },
      rut_comercio:    { type: "STRING", nullable: true },
      fecha:           { type: "STRING", nullable: true },
      monto_total:     { type: "INTEGER", nullable: true },
      items:           { type: "ARRAY", items: { type: "STRING" } }
    },
    required: %w[nombre_comercio rut_comercio fecha monto_total items]
  }.freeze

  def initialize(api_key = nil)
    @api_key = api_key || ENV["GEMINI_API_KEY"]
    raise "GEMINI_API_KEY no configurada" if @api_key.blank?
  end

  def extract_from_blob(blob)
    blob.open do |file|
      texto = pdf?(blob) ? extract_pdf_text(file.path) : ""

      if texto.length > MIN_TEXTO_PDF
        Rails.logger.info "[GeminiExtractor] PDF con texto (#{texto.length} caracteres), se envía como texto"
        call_gemini([ { text: "#{PROMPT}\n\nTexto de la boleta:\n#{texto[0, MAX_TEXTO_PDF]}" } ])
      else
        Rails.logger.info "[GeminiExtractor] #{blob.content_type} sin texto, se envía el archivo para OCR"
        call_gemini([ { text: PROMPT }, inline_file(file.path, blob.content_type) ])
      end
    end
  end

  private

  def pdf?(blob)
    blob.content_type == "application/pdf"
  end

  def extract_pdf_text(path)
    require "pdf-reader"
    PDF::Reader.new(path).pages.map(&:text).join("\n").strip
  rescue => e
    Rails.logger.warn "[GeminiExtractor] No se pudo leer el texto del PDF: #{e.message}"
    ""
  end

  def inline_file(path, content_type)
    { inline_data: { mime_type: content_type, data: Base64.strict_encode64(File.binread(path)) } }
  end

  def call_gemini(parts)
    res  = connection.post(API_URL, { contents: [ { parts: parts } ], generationConfig: generation_config })
    body = res.body.is_a?(Hash) ? res.body : {}
    raise "Gemini API error #{res.status}: #{body.dig("error", "message") || "sin detalle"}" unless res.success?

    candidate = body.dig("candidates", 0) || {}
    raw = Array(candidate.dig("content", "parts")).filter_map { |part| part["text"] }.join.strip
    raise "Respuesta vacía de Gemini (finishReason: #{candidate["finishReason"] || "desconocido"})" if raw.empty?

    Rails.logger.info "[GeminiExtractor] respuesta: #{raw[0, 300]}"
    normalize(parse_json(raw))
  end

  def connection
    Faraday.new(headers: { "x-goog-api-key" => @api_key }) do |f|
      f.request :json
      f.response :json
      f.options.timeout = 60
      f.options.open_timeout = 10
    end
  end

  def generation_config
    config = {
      temperature: 0,
      maxOutputTokens: 4096,
      responseMimeType: "application/json",
      responseSchema: RESPONSE_SCHEMA
    }
    # En gemini-2.5-flash el "thinking" viene activado y consume maxOutputTokens,
    # lo que puede dejar la respuesta vacía. Para extraer datos no hace falta.
    config[:thinkingConfig] = { thinkingBudget: 0 } if MODEL.include?("2.5-flash")
    config
  end

  def parse_json(raw)
    limpio = raw.gsub(/```(?:json)?/, "").strip
    datos  = JSON.parse(limpio[/\{.*\}/m] || limpio)
    raise "Gemini no devolvió un objeto JSON" unless datos.is_a?(Hash)
    datos
  rescue JSON::ParserError
    raise "Gemini devolvió un JSON inválido: #{raw[0, 120]}"
  end

  def normalize(datos)
    {
      nombre_comercio: datos["nombre_comercio"].to_s.strip.presence,
      rut_comercio:    datos["rut_comercio"].to_s.strip.presence,
      fecha:           parse_fecha(datos["fecha"]),
      monto_total:     parse_monto(datos["monto_total"]),
      items:           Array(datos["items"]).map { |item| item.to_s.strip }.reject(&:blank?).join("\n")
    }
  end

  # Acepta 11332, 11332.0, "$11.332" y "11.332,00": en pesos chilenos el punto separa miles
  # y los decimales no se usan.
  def parse_monto(valor)
    monto =
      if valor.is_a?(Numeric)
        valor.round
      else
        valor.to_s.strip.sub(/[.,]\d{1,2}\z/, "").gsub(/[^0-9]/, "").presence&.to_i
      end

    monto if monto&.positive?
  end

  def parse_fecha(valor)
    texto = valor.to_s.strip
    FORMATOS_FECHA.each do |formato|
      fecha = Date.strptime(texto, formato)
      return fecha if fecha.year.between?(2000, Date.current.year + 1)
    rescue Date::Error
      next
    end
    nil
  end
end

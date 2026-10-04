require "faraday"
require "base64"
require "json"

class GeminiExtractor
  GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent"

  PROMPT = 'Extrae de esta boleta chilena estos campos en JSON puro sin markdown: {"nombre_comercio":"...","rut_comercio":"XX.XXX.XXX-X","fecha":"YYYY-MM-DD","monto_total":numero_entero,"items":["item1","item2"]}. Solo JSON, sin explicaciones.'

  def initialize(api_key = nil)
    @api_key = api_key || ENV["GEMINI_API_KEY"]
    raise "GEMINI_API_KEY no configurada" if @api_key.blank?
  end

  def extract_from_blob(blob)
    blob.open do |file|
      text = extract_pdf_text(file.path)
      if text.present? && text.length > 50
        Rails.logger.info "[GeminiExtractor] Usando texto PDF: #{text.length} chars"
        return call_gemini_text(text)
      end
      Rails.logger.info "[GeminiExtractor] PDF sin texto, enviando como binario"
      call_gemini_binary(file.path, blob.content_type)
    end
  end

  private

  def extract_pdf_text(path)
    require "pdf-reader"
    PDF::Reader.new(path).pages.map(&:text).join("\n").strip
  rescue => e
    Rails.logger.warn "[GeminiExtractor] PDF text error: #{e.message}"
    ""
  end

  def call_gemini_text(text)
    body = {
      contents: [{ parts: [{ text: "#{PROMPT}\n\nBoleta:\n#{text[0..2000]}" }] }],
      generationConfig: { temperature: 0, maxOutputTokens: 300 }
    }
    call_gemini(body)
  end

  def call_gemini_binary(path, content_type)
    data = Base64.strict_encode64(File.binread(path))
    body = {
      contents: [{ parts: [
        { text: PROMPT },
        { inline_data: { mime_type: content_type, data: data } }
      ]}],
      generationConfig: { temperature: 0, maxOutputTokens: 300 }
    }
    call_gemini(body)
  end

  def call_gemini(body)
    conn = Faraday.new { |f| f.request :json; f.response :json; f.options.timeout = 90; f.options.open_timeout = 10 }
    res = conn.post("#{GEMINI_API_URL}?key=#{@api_key}", body)
    raise "Gemini API error: #{res.status}" unless res.success?
    raw = res.body.dig("candidates", 0, "content", "parts", 0, "text").to_s.strip
    Rails.logger.info "[GeminiExtractor] raw: #{raw[0..300]}"
    clean = raw.gsub(/```json\n?/, "").gsub(/```\n?/, "").strip
    match = clean.match(/\{.*\}/m)
    raise "JSON no encontrado en respuesta" unless match
    normalize(JSON.parse(match[0]))
  end

  def normalize(d)
    {
      nombre_comercio: d["nombre_comercio"].to_s.strip.presence,
      rut_comercio:    d["rut_comercio"].to_s.strip.presence,
      fecha:           (Date.parse(d["fecha"].to_s) rescue nil),
      monto_total:     d["monto_total"].to_s.gsub(/[^0-9]/, "").presence&.to_i,
      items:           d["items"].is_a?(Array) ? d["items"].join("\n") : d["items"].to_s
    }
  end
end
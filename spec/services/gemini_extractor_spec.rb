require "rails_helper"

# La API de Gemini se simula: estas pruebas no hacen llamadas reales ni gastan cuota.
RSpec.describe GeminiExtractor do
  subject(:extractor) { described_class.new("clave-de-prueba") }

  let(:conexion) { double("conexion") }
  let(:datos_boleta) do
    {
      nombre_comercio: " Lider ",
      rut_comercio: "76.134.941-4",
      fecha: "2026-09-30",
      monto_total: 11_332,
      items: [ "Pan", "Leche" ]
    }
  end

  before { allow(extractor).to receive(:connection).and_return(conexion) }

  def archivo(content_type)
    blob = double("blob", content_type: content_type)
    allow(blob).to receive(:open) do |&bloque|
      Tempfile.create("boleta") do |file|
        file.write("contenido de prueba")
        file.flush
        bloque.call(file)
      end
    end
    blob
  end

  def respuesta_ok(datos)
    texto = { "text" => datos.to_json }
    candidato = { "finishReason" => "STOP", "content" => { "parts" => [ texto ] } }
    double("respuesta", success?: true, status: 200, body: { "candidates" => [ candidato ] })
  end

  def respuesta_error(status, mensaje)
    double("respuesta", success?: false, status: status, body: { "error" => { "message" => mensaje } })
  end

  describe "#extract_from_blob" do
    it "envía la imagen a Gemini y normaliza los datos" do
      allow(conexion).to receive(:post).and_return(respuesta_ok(datos_boleta))

      resultado = extractor.extract_from_blob(archivo("image/jpeg"))

      expect(resultado).to eq({
        nombre_comercio: "Lider",
        rut_comercio: "76.134.941-4",
        fecha: Date.new(2026, 9, 30),
        monto_total: 11_332,
        items: "Pan\nLeche"
      })
      expect(conexion).to have_received(:post) do |url, payload|
        expect(url).to include(described_class::MODELOS.first)
        expect(payload[:contents].first[:parts].last).to have_key(:inline_data)
      end
    end

    it "envía solo el texto cuando el PDF ya lo trae" do
      texto = "SUPERMERCADO LIDER RUT 76.134.941-4 TOTAL $11.332 " * 3
      allow(extractor).to receive(:extract_pdf_text).and_return(texto)
      allow(conexion).to receive(:post).and_return(respuesta_ok(datos_boleta))

      extractor.extract_from_blob(archivo("application/pdf"))

      expect(conexion).to have_received(:post) do |_url, payload|
        partes = payload[:contents].first[:parts]
        expect(partes.size).to eq(1)
        expect(partes.first[:text]).to include("TOTAL $11.332")
      end
    end

    it "usa el siguiente modelo si el primero está saturado" do
      allow(conexion).to receive(:post).and_return(respuesta_error(503, "high demand"), respuesta_ok(datos_boleta))

      resultado = extractor.extract_from_blob(archivo("image/png"))

      expect(resultado[:monto_total]).to eq(11_332)
      expect(conexion).to have_received(:post).twice
    end

    it "falla con el detalle del error si ningún modelo responde" do
      allow(conexion).to receive(:post).and_return(respuesta_error(503, "high demand"))

      expect { extractor.extract_from_blob(archivo("image/png")) }
        .to raise_error(described_class::ModeloNoDisponible, /503: high demand/)
    end

    it "no reintenta cuando el error es de la solicitud" do
      allow(conexion).to receive(:post).and_return(respuesta_error(400, "Invalid JSON payload"))

      expect { extractor.extract_from_blob(archivo("image/png")) }.to raise_error(RuntimeError, /400/)
      expect(conexion).to have_received(:post).once
    end

    { 11_332.0 => 11_332, "$11.332" => 11_332, "11.332,00" => 11_332, 0 => nil, nil => nil }.each do |entrada, esperado|
      it "interpreta el monto #{entrada.inspect} como #{esperado.inspect}" do
        allow(conexion).to receive(:post).and_return(respuesta_ok(datos_boleta.merge(monto_total: entrada)))

        resultado = extractor.extract_from_blob(archivo("image/jpeg"))

        expect(resultado[:monto_total]).to eq(esperado)
      end
    end
  end
end

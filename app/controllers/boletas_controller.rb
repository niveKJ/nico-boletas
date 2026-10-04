# app/controllers/boletas_controller.rb
class BoletasController < ApplicationController
  before_action :set_boleta, only: %i[show edit update destroy]

  # GET /boletas
  def index
    @boletas       = Boleta.order(created_at: :desc)
    @total_boletas = @boletas.size
    @completadas   = @boletas.count { |b| b.estado == "completado" }
    @monto_total   = @boletas.sum { |b| b.monto_total.to_f }
  end

  # GET /boletas/new
  def new
    @boleta = Boleta.new
  end

  # POST /boletas
  def create
    unless params.dig(:boleta, :archivo).present?
      @boleta = Boleta.new
      flash.now[:alert] = "Debes subir un archivo (PDF, JPG o PNG)."
      render :new, status: :unprocessable_entity
      return
    end

    @boleta = Boleta.new(estado: "procesando")
    @boleta.archivo.attach(params[:boleta][:archivo])

    unless @boleta.save
      flash.now[:alert] = @boleta.errors.full_messages.to_sentence
      render :new, status: :unprocessable_entity
      return
    end

    begin
      extractor = GeminiExtractor.new
      datos     = extractor.extract_from_blob(@boleta.archivo.blob)

      @boleta.update_columns(
        nombre_comercio: datos[:nombre_comercio],
        rut_comercio:    datos[:rut_comercio],
        fecha:           datos[:fecha],
        monto_total:     datos[:monto_total],
        items:           datos[:items],
        estado:          "extraido"
      )

      flash[:notice] = "✅ Boleta analizada. Revisa los datos y confirma."
      redirect_to edit_boleta_path(@boleta)

    rescue => e
      Rails.logger.error "[BoletasController] Extracción fallida: #{e.class} #{e.message}"
      @boleta.update_columns(estado: "error")
      flash[:alert] = "⚠️ No se pudo extraer automáticamente. Ingresa los datos manualmente."
      redirect_to edit_boleta_path(@boleta)
    end
  end

  # GET /boletas/:id
  def show; end

  # GET /boletas/:id/edit
  def edit; end

  # PATCH /boletas/:id
  def update
    if @boleta.update(boleta_params.merge(estado: "completado"))
      flash[:notice] = "✅ Boleta guardada correctamente."
      redirect_to @boleta
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /boletas/:id
  def destroy
    @boleta.destroy
    redirect_to boletas_path, notice: "Boleta eliminada."
  end

  private

  def set_boleta
    @boleta = Boleta.find(params[:id])
  end

  def boleta_params
    params.require(:boleta).permit(:nombre_comercio, :rut_comercio, :fecha, :monto_total, :items)
  end
end
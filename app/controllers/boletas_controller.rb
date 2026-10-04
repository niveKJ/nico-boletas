class BoletasController < ApplicationController
  before_action :set_boleta, only: [:show, :edit, :update]

  def index
    @boletas = Boleta.order(created_at: :desc)
  end

  def new
    @boleta = Boleta.new
  end

  def create
    @boleta = Boleta.new(estado: "pendiente")

    if @boleta.save
      @boleta.archivo.attach(params[:boleta][:archivo]) if params.dig(:boleta, :archivo)
      
      if @boleta.archivo.attached?
        @boleta.update_columns(estado: "procesando")
        resultado = GeminiExtractor.new(@boleta).call

        if resultado[:error]
          @boleta.update_columns(estado: "error")
        else
          @boleta.update_columns(
            nombre_comercio: resultado[:nombre_comercio],
            rut_comercio:    resultado[:rut_comercio],
            fecha:           resultado[:fecha],
            monto_total:     resultado[:monto_total],
            estado:          "completado"
          )
        end
      end

      redirect_to boleta_path(@boleta), notice: "Boleta procesada correctamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def edit
  end

  def update
    if @boleta.update(boleta_params)
      redirect_to boleta_path(@boleta), notice: "Boleta actualizada."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_boleta
    @boleta = Boleta.find(params[:id])
  end

  def boleta_params
    params.require(:boleta).permit(:nombre_comercio, :rut_comercio, :fecha, :monto_total, :estado, :archivo)
  end
end
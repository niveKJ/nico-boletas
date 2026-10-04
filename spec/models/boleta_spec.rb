require "rails_helper"

RSpec.describe Boleta, type: :model do
  describe "validaciones" do
    it "es válida con estado pendiente" do
      boleta = Boleta.new(estado: "pendiente")
      expect(boleta).to be_valid
    end

    it "no es válida sin estado" do
      boleta = Boleta.new(estado: nil)
      expect(boleta).not_to be_valid
    end

    it "no es válida con un estado no permitido" do
      boleta = Boleta.new(estado: "inventado")
      expect(boleta).not_to be_valid
    end
  end

  describe "estados" do
    it "tiene los estados correctos definidos" do
      expect(Boleta::ESTADOS).to eq(%w[pendiente procesando completado error])
    end
  end

  describe "scopes" do
    it "scope completadas retorna solo las boletas completadas" do
      expect(Boleta).to respond_to(:completadas)
    end
  end
end
require "rails_helper"

RSpec.describe Boleta, type: :model do
  describe "validaciones" do
    it "se puede crear solo con el estado, antes de extraer los datos" do
      expect(Boleta.new(estado: "procesando")).to be_valid
    end

    it "rechaza un estado que no existe" do
      expect(Boleta.new(estado: "inventado")).not_to be_valid
    end

    it "exige comercio, fecha y monto al confirmar" do
      boleta = Boleta.create!(estado: "procesando")

      expect(boleta.update(estado: "completado")).to be(false)
      expect(boleta.errors.attribute_names).to contain_exactly(:nombre_comercio, :fecha, :monto_total)
    end

    it "rechaza un monto que no es mayor que cero" do
      boleta = FactoryBot.create(:boleta)

      expect(boleta.update(monto_total: 0)).to be(false)
      expect(boleta.errors.full_messages).to include("Monto total debe ser mayor que 0")
    end
  end

  describe ".completadas" do
    it "devuelve solo las boletas confirmadas" do
      completada = FactoryBot.create(:boleta, :completada)
      FactoryBot.create(:boleta)

      expect(Boleta.completadas).to contain_exactly(completada)
    end
  end

  describe "#items_array" do
    it "separa los ítems por línea y descarta las líneas vacías" do
      expect(Boleta.new(items: "Pan\n\n  Leche  \n").items_array).to eq([ "Pan", "Leche" ])
    end

    it "devuelve una lista vacía si no hay ítems" do
      expect(Boleta.new.items_array).to eq([])
    end
  end

  describe "#fecha_formateada" do
    it "usa el formato chileno DD/MM/AAAA" do
      expect(Boleta.new(fecha: Date.new(2026, 9, 30)).fecha_formateada).to eq("30/09/2026")
    end

    it "muestra una raya si no hay fecha" do
      expect(Boleta.new.fecha_formateada).to eq("—")
    end
  end
end

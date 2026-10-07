require "rails_helper"

RSpec.describe "Boletas", type: :request do
  describe "PATCH /boletas/:id" do
    it "guarda los datos corregidos y marca la boleta como completada" do
      boleta = FactoryBot.create(:boleta, nombre_comercio: "LIDR")

      patch boleta_path(boleta), params: { boleta: { nombre_comercio: "Lider" } }

      expect(response).to redirect_to(boleta_path(boleta))
      expect(boleta.reload).to have_attributes(nombre_comercio: "Lider", estado: "completado")
    end
  end

  describe "DELETE /boletas/:id" do
    it "elimina la boleta y vuelve al listado" do
      boleta = FactoryBot.create(:boleta)

      expect { delete boleta_path(boleta) }.to change(Boleta, :count).by(-1)
      expect(response).to redirect_to(boletas_path)
    end
  end
end

FactoryBot.define do
  factory :boleta do
    estado { "extraido" }
    nombre_comercio { "Supermercado Lider" }
    rut_comercio { "76.134.941-4" }
    fecha { Date.new(2026, 9, 30) }
    monto_total { 11_332 }
    items { "Pan\nLeche" }

    trait :completada do
      estado { "completado" }
    end
  end
end

FactoryBot.define do
  factory :boleta do
    estado { "pendiente" }
    nombre_comercio { Faker::Company.name }
    rut_comercio { "76.#{Faker::Number.number(digits: 3)}.#{Faker::Number.number(digits: 3)}-#{Faker::Number.number(digits: 1)}" }
    fecha { Faker::Date.backward(days: 30) }
    monto_total { Faker::Number.decimal(l_digits: 4, r_digits: 2) }

    trait :completada do
      estado { "completado" }
    end

    trait :con_error do
      estado { "error" }
    end
  end
end
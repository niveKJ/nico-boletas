class Boleta < ApplicationRecord
  has_one_attached :archivo

  ESTADOS = %w[ procesando extraido completado error ].freeze

  scope :completadas, -> { where(estado: "completado") }

  validates :estado, inclusion: { in: ESTADOS }

  # Los datos solo son obligatorios al confirmar: la boleta se crea vacía y se
  # completa con lo que extrae la IA o con lo que ingresa la persona.
  with_options on: :update do
    validates :nombre_comercio, presence: { message: "no puede estar en blanco" }
    validates :fecha,           presence: { message: "no puede estar en blanco" }
    validates :monto_total,     numericality: { greater_than: 0, message: "debe ser mayor que 0" }
  end

  def items_array
    items.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def fecha_formateada
    fecha&.strftime("%d/%m/%Y") || "—"
  end
end

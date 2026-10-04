class Boleta < ApplicationRecord
  self.table_name = "boletas"

  ESTADOS = %w[pendiente procesando completado error].freeze

  validates :estado, presence: true, inclusion: { in: ESTADOS }

  scope :completadas, -> { where(estado: "completado") }
  scope :con_error, -> { where(estado: "error") }
  scope :pendientes, -> { where(estado: "pendiente") }

  has_one_attached :archivo
end
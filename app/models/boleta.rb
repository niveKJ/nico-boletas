# app/models/boleta.rb
class Boleta < ApplicationRecord
  has_one_attached :archivo

  ESTADOS = %w[procesando extraido completado error].freeze

  validates :nombre_comercio, presence: true, on: :update
  validates :fecha,           presence: true, on: :update
  validates :monto_total,     presence: true,
                              numericality: { greater_than: 0 }, on: :update

  def items_array
    return [] if items.blank?
    items.to_s.split("\n").map(&:strip).reject(&:blank?)
  end

  def monto_formateado
    return "-" if monto_total.blank?
    "$#{monto_total.to_i.to_s.reverse.gsub(/(\d{3})(?=\d)/, '\1.').reverse}"
  end

  def fecha_formateada
    fecha&.strftime("%d/%m/%Y") || "-"
  end
end
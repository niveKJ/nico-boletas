class CreateBoletas < ActiveRecord::Migration[8.1]
  def change
    create_table :boletas do |t|
      t.string :nombre_comercio
      t.string :rut_comercio
      t.date :fecha
      t.decimal :monto_total
      t.string :estado

      t.timestamps
    end
  end
end

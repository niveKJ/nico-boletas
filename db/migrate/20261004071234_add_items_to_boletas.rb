class AddItemsToBoletas < ActiveRecord::Migration[8.1]
  def change
    add_column :boletas, :items, :text
  end
end

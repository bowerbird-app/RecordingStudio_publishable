class CreateWidgets < ActiveRecord::Migration[8.1]
  def change
    create_table :widgets, id: :uuid do |t|
      t.string :title
      t.text :summary

      t.timestamps
    end
  end
end

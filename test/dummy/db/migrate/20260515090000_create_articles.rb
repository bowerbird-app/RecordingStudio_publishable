class CreateArticles < ActiveRecord::Migration[8.1]
  def change
    create_table :articles, id: :uuid do |t|
      t.string :title
      t.text :excerpt

      t.timestamps
    end
  end
end
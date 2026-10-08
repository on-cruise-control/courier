class CreateDefaultTemplates < ActiveRecord::Migration[7.1]
  def change
    create_table :default_templates do |t|
      t.string :name, null: false
      t.string :platform, null: false, default: 'all'
      t.string :category, null: false
      t.jsonb :content, null: false, default: {}
      t.string :language, null: false, default: 'en'
      t.timestamps
    end
    add_index :default_templates, [:name, :platform], unique: true

    create_table :default_template_exclusions do |t|
      t.references :inbox, null: false, index: false, foreign_key: { on_delete: :cascade }
      t.references :default_template, null: false, foreign_key: { on_delete: :cascade }
      t.timestamps
    end
    add_index :default_template_exclusions, [:inbox_id, :default_template_id], unique: true, name: 'index_default_template_exclusions_unique'
  end
end

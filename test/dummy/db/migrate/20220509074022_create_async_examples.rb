class CreateAsyncExamples < ActiveRecord::Migration[7.0]
  def change
    create_table :async_examples do |t|
      t.string :testfield

      t.timestamps
    end
  end
end

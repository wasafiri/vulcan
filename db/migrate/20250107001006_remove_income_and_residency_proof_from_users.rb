class RemoveIncomeAndResidencyProofFromUsers < ActiveRecord::Migration[8.0]
  def change
    remove_column :users, :income_proof, :string
    remove_column :users, :residency_proof, :string
  end
end

class CreateTotpCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :totp_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :secret, null: false
      t.string :nickname, null: false
      t.datetime :last_used_at, null: false

      t.timestamps
    end
  end
end

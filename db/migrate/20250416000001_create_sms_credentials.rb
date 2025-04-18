class CreateSmsCredentials < ActiveRecord::Migration[8.0]
  def change
    create_table :sms_credentials do |t|
      t.references :user, null: false, foreign_key: true
      t.string :phone_number, null: false
      t.datetime :last_sent_at, null: false
      t.string :code_digest
      t.datetime :code_expires_at

      t.timestamps
    end
  end
end

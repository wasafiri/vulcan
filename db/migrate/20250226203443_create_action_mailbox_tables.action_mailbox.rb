# This migration comes from action_mailbox (originally 20180917164000)
class CreateActionMailboxTables < ActiveRecord::Migration[8.0]
  def change
    create_table :action_mailbox_inbound_emails, id: primary_key_type do |t|
      t.integer :status, default: 0, null: false
      t.string  :message_id, null: false
      t.string  :message_checksum, null: false

      t.timestamps

      t.index %i[message_id message_checksum], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
    end
  end

  private

  def primary_key_type
    config = Rails.configuration.generators
    config.options[config.orm][:primary_key_type] || :primary_key
  end
end

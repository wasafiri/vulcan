class AddAuditableToEvents < ActiveRecord::Migration[8.0]
  def change
    add_reference :events, :auditable, polymorphic: true
  end
end

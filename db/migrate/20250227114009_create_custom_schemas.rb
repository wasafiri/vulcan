# This migration is no longer needed as we're using the default schema
# for all database connections in Heroku
class CreateCustomSchemas < ActiveRecord::Migration[8.0]
  def up
    # No schema creation needed
  end

  def down
    # No schema removal needed
  end
end

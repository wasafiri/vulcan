class CreateCustomSchemas < ActiveRecord::Migration[8.0]
  def up
    execute "CREATE SCHEMA IF NOT EXISTS cache"
    execute "CREATE SCHEMA IF NOT EXISTS queue"
    execute "CREATE SCHEMA IF NOT EXISTS cable"
  end

  def down
    execute "DROP SCHEMA IF EXISTS cache CASCADE"
    execute "DROP SCHEMA IF EXISTS queue CASCADE"
    execute "DROP SCHEMA IF EXISTS cable CASCADE"
  end
end

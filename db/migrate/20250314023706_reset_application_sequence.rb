class ResetApplicationSequence < ActiveRecord::Migration[8.0]
  def up
    # For PostgreSQL only - ensure high non-sequential IDs for security
    if ActiveRecord::Base.connection.adapter_name.downcase.include?('postgresql')
      # Start with a high base number and add random offset for security (prevent enumeration attacks)
      base = 980_000_000
      random_offset = Random.rand(100_000)
      target = base + random_offset
      
      # Get current max ID to ensure we don't go backwards
      max_id = execute("SELECT MAX(id) FROM applications").first["max"]
      target = [target, (max_id.to_i + random_offset)].max if max_id
      
      execute("ALTER SEQUENCE applications_id_seq RESTART WITH #{target}")
      puts "Set applications_id_seq to start at #{target} with randomization for security"
    else
      puts "Skipping sequence reset for non-PostgreSQL database"
    end
  end

  def down
    # No need to undo this migration
    puts "No rollback necessary for sequence adjustment"
  end
end

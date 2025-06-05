class FixProofStatusInconsistencies < ActiveRecord::Migration[8.0]
  def up
    ActiveRecord::Base.transaction do
      # Check if income_proof_status column exists before working with it
      if column_exists?(:applications, :income_proof_status)
        # Find applications with income_proof_status set to 'approved' or 'rejected'
        # but don't have the file attached
        income_inconsistent_ids = execute(<<-SQL).to_a.map { |r| r['id'] || r[:id] }
          SELECT a.id
          FROM applications a
          LEFT JOIN active_storage_attachments asa ON
            asa.record_id = a.id AND
            asa.record_type = 'Application' AND
            asa.name = 'income_proof'
          WHERE a.income_proof_status IN (1, 2) -- approved (1) or rejected (2)
            AND asa.id IS NULL
        SQL

        # Ensure IDs are integers to prevent SQL injection
        income_inconsistent_ids = income_inconsistent_ids.map(&:to_i)

        # Reset income proof status if inconsistent
        if income_inconsistent_ids.any?
          income_ids_list = income_inconsistent_ids.join(',')
          if income_ids_list.present?
            execute(<<-SQL)
              UPDATE applications
              SET income_proof_status = 0 -- not_reviewed
              WHERE id IN (#{income_ids_list})
            SQL
          end

          puts "Reset income_proof_status to 'not_reviewed' for #{income_inconsistent_ids.size} applications"
        else
          puts 'No income proof inconsistencies found'
        end
      else
        puts 'income_proof_status column does not exist, skipping income proof check'
      end

      # Check if residency_proof_status column exists before working with it
      if column_exists?(:applications, :residency_proof_status)
        # Find applications with residency_proof_status set to 'approved' or 'rejected'
        # but don't have the file attached
        residency_inconsistent_ids = execute(<<-SQL).to_a.map { |r| r['id'] || r[:id] }
          SELECT a.id#{' '}
          FROM applications a
          LEFT JOIN active_storage_attachments asa ON#{' '}
            asa.record_id = a.id AND#{' '}
            asa.record_type = 'Application' AND
            asa.name = 'residency_proof'
          WHERE a.residency_proof_status IN (1, 2) -- approved (1) or rejected (2)
            AND asa.id IS NULL
        SQL

        # Ensure IDs are integers to prevent SQL injection
        residency_inconsistent_ids = residency_inconsistent_ids.map(&:to_i)

        # Reset residency proof status if inconsistent
        if residency_inconsistent_ids.any?
          residency_ids_list = residency_inconsistent_ids.join(',')
          if residency_ids_list.present?
            execute(<<-SQL)
              UPDATE applications
              SET residency_proof_status = 0 -- not_reviewed
              WHERE id IN (#{residency_ids_list})
            SQL
          end

          puts "Reset residency_proof_status to 'not_reviewed' for #{residency_inconsistent_ids.size} applications"
        else
          puts 'No residency proof inconsistencies found'
        end
      else
        puts 'residency_proof_status column does not exist, skipping residency proof check'
      end
    end
  end

  def down
    puts 'This migration cannot be reversed as it corrects data inconsistencies'
  end
end

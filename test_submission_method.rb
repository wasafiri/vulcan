# Get an application and an admin user to work with
app = Application.first
admin = Admin.first

# First, test with nil submission_method
error = StandardError.new("Test error")
metadata = { ip_address: '127.0.0.1' }

# Should not raise error due to our fallback handling
begin
  result = ProofAttachmentService.record_failure(app, :income, error, admin, nil, metadata)
  puts "Audit with nil submission_method created successfully? #{result != nil}"

  # Check if the audit record has a submission_method
  audit = ProofSubmissionAudit.last
  puts "Audit submission_method: #{audit.submission_method}"
rescue StandardError => e
  puts "Error with nil submission_method: #{e.message}"
end

# Test with invalid symbol
begin
  result2 = ProofAttachmentService.record_failure(app, :income, error, admin, :not_a_valid_method, metadata)
  puts "Audit with invalid submission_method created successfully? #{result2 != nil}"

  # Check if the audit record has a submission_method
  audit2 = ProofSubmissionAudit.last
  puts "Audit2 submission_method: #{audit2.submission_method}"
rescue StandardError => e
  puts "Error with invalid submission_method: #{e.message}"
end

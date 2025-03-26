require "test_helper"

class PrintQueueItemTest < ActiveSupport::TestCase
  def setup
    @constituent = users(:constituent_alex)
    @admin = users(:admin_david)
    @application = applications(:one)
    
    @pending_letter = PrintQueueItem.new(
      letter_type: :registration_confirmation,
      status: :pending,
      constituent: @constituent,
      application: @application
    )
    
    # Attach a test PDF
    test_pdf = fixture_file_upload("test.pdf", "application/pdf")
    @pending_letter.pdf_letter.attach(io: test_pdf.open, filename: "test_letter.pdf")
  end
  
  test "should be valid with required attributes" do
    assert @pending_letter.valid?
  end
  
  test "should require letter_type" do
    @pending_letter.letter_type = nil
    assert_not @pending_letter.valid?
    assert_includes @pending_letter.errors.full_messages, "Letter type can't be blank"
  end
  
  test "should require pdf_letter attachment on create" do
    letter = PrintQueueItem.new(
      letter_type: :registration_confirmation,
      status: :pending,
      constituent: @constituent,
      application: @application
    )
    
    assert_not letter.valid?
    assert_includes letter.errors.full_messages, "Pdf letter can't be blank"
  end
  
  test "should require constituent" do
    @pending_letter.constituent = nil
    assert_not @pending_letter.valid?
    assert_includes @pending_letter.errors.full_messages, "Constituent must exist"
  end
  
  test "application should be optional" do
    @pending_letter.application = nil
    assert @pending_letter.valid?
  end
  
  test "should set default status to pending" do
    letter = PrintQueueItem.new(
      letter_type: :registration_confirmation,
      constituent: @constituent
    )
    letter.pdf_letter.attach(
      io: fixture_file_upload("test.pdf", "application/pdf").open, 
      filename: "test_letter.pdf"
    )
    
    letter.save
    assert_equal "pending", letter.status
  end
  
  test "should have scopes for filtering" do
    assert_respond_to PrintQueueItem, :pending
    assert_respond_to PrintQueueItem, :recent
  end
  
  test "should mark as printed" do
    @pending_letter.save
    
    assert_changes -> { @pending_letter.status }, from: "pending", to: "printed" do
      @pending_letter.mark_as_printed(@admin)
    end
    
    assert_equal @admin.id, @pending_letter.admin_id
    assert_not_nil @pending_letter.printed_at
  end
end

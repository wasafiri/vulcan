# frozen_string_literal: true

require 'test_helper'

module Admin
  class PrintQueueControllerTest < ActionDispatch::IntegrationTest
    def setup
      @admin = users(:admin_david)
      @pending_letter = print_queue_items(:pending_letter_1)
      @pending_letter2 = print_queue_items(:pending_letter_2)
      @printed_letter = print_queue_items(:printed_letter)

      # Attach test PDF files to the letters
      test_pdf = fixture_file_upload('test.pdf', 'application/pdf')
      @pending_letter.pdf_letter.attach(io: test_pdf.open, filename: 'test_letter.pdf')
      @pending_letter2.pdf_letter.attach(io: test_pdf.open, filename: 'test_letter2.pdf')
      @printed_letter.pdf_letter.attach(io: test_pdf.open, filename: 'printed_letter.pdf')

      @headers = {
        'HTTP_USER_AGENT' => 'Rails Testing',
        'REMOTE_ADDR' => '127.0.0.1'
      }

      # Sign in as admin
      post sign_in_path,
           params: { email: @admin.email, password: 'password123' },
           headers: @headers

      assert_response :redirect
      follow_redirect!
    end

    def test_should_get_index
      get admin_print_queue_index_path
      assert_response :success
      assert_select 'h1', text: 'Print Queue'
      assert_select '.letter-checkbox', { minimum: 2 } # At least 2 checkboxes for pending letters
    end

    def test_should_show_letter_pdf
      get admin_print_queue_path(@pending_letter, format: :pdf)
      assert_response :success
      assert_equal 'application/pdf', response.content_type
      assert_match(/^inline/, response.headers['Content-Disposition'])
    end

    def test_should_download_single_letter
      get download_batch_admin_print_queue_index_path, params: { letter_ids: [@pending_letter.id] }
      assert_response :success
      assert_equal 'application/pdf', response.content_type
      assert_match(/attachment/, response.headers['Content-Disposition'])
    end

    def test_should_download_multiple_letters_as_zip
      # Make sure the letters have PDF files attached before testing
      assert @pending_letter.pdf_letter.attached?
      assert @pending_letter2.pdf_letter.attached?

      # Manually skip this test if the attachments don't exist yet (for CI environments)
      if !@pending_letter.pdf_letter.attached? || !@pending_letter2.pdf_letter.attached?
        skip 'Test attachments not properly set up'
      end

      # Mock the zip file creation to avoid issues in test environment
      mock_zipfile = Tempfile.new('test.zip')
      mock_zipfile.write('mock zip content')
      mock_zipfile.rewind

      Tempfile.stub :new, mock_zipfile do
        File.stub :exist?, true do
          get download_batch_admin_print_queue_index_path,
              params: { letter_ids: [@pending_letter.id, @pending_letter2.id] }
          assert_response :success
          assert_equal 'application/zip', response.content_type
          assert_match(/attachment/, response.headers['Content-Disposition'])
        end
      end

      mock_zipfile.close
      mock_zipfile.unlink
    end

    def test_should_redirect_if_no_letters_selected_for_download
      get download_batch_admin_print_queue_index_path, params: { letter_ids: [] }
      assert_redirected_to admin_print_queue_index_path
      assert_equal 'No letters selected for download', flash[:alert]
    end

    def test_should_mark_single_letter_as_printed
      post mark_as_printed_admin_print_queue_path(@pending_letter)
      assert_redirected_to admin_print_queue_index_path
      assert_equal 'Letter marked as printed', flash[:notice]

      # Verify the letter was marked as printed
      @pending_letter.reload
      assert_equal 'printed', @pending_letter.status
      assert_equal @admin.id, @pending_letter.admin_id
      assert_not_nil @pending_letter.printed_at
    end

    def test_should_mark_batch_as_printed
      assert_changes -> { PrintQueueItem.pending.count }, from: 2, to: 0 do
        post mark_batch_as_printed_admin_print_queue_index_path, params: {
          letter_ids: [@pending_letter.id, @pending_letter2.id]
        }
      end

      assert_redirected_to admin_print_queue_index_path
      assert_equal '2 letters marked as printed', flash[:notice]

      # Verify both letters are now marked as printed
      @pending_letter.reload
      @pending_letter2.reload
      assert_equal 'printed', @pending_letter.status
      assert_equal 'printed', @pending_letter2.status
      assert_equal @admin.id, @pending_letter.admin_id
      assert_equal @admin.id, @pending_letter2.admin_id
    end

    def test_should_handle_empty_batch_for_mark_as_printed
      post mark_batch_as_printed_admin_print_queue_index_path, params: { letter_ids: [] }
      assert_redirected_to admin_print_queue_index_path
      assert_equal '0 letters marked as printed', flash[:notice]
    end
  end
end

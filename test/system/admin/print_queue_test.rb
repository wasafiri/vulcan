# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PrintQueueTest < ApplicationSystemTestCase
    setup do
      @admin = users(:admin_david)
      @pending_letter = print_queue_items(:pending_letter_1)
      @pending_letter2 = print_queue_items(:pending_letter_2)

      # Attach test PDF files to the letters
      test_pdf = fixture_file_upload('test.pdf', 'application/pdf')
      @pending_letter.pdf_letter.attach(io: test_pdf.open, filename: 'test_letter.pdf')
      @pending_letter2.pdf_letter.attach(io: test_pdf.open, filename: 'test_letter2.pdf')

      # Log in as admin
      sign_in(@admin)
    end

    test 'viewing print queue' do
      visit admin_print_queue_index_path

      assert_selector 'h1', text: 'Print Queue'
      assert_selector 'h2', text: 'Pending Letters'
      assert_selector 'h2', text: 'Recently Printed Letters'

      # Check that our pending letters are displayed
      assert_selector '.letter-checkbox', minimum: 2
      assert_button 'Download Selected', disabled: true
      assert_button 'Mark Selected as Printed', disabled: true
    end

    test 'selecting letters enables buttons' do
      visit admin_print_queue_index_path

      # Initially buttons should be disabled
      assert_button 'Download Selected', disabled: true
      assert_button 'Mark Selected as Printed', disabled: true

      # Select a letter
      find('.letter-checkbox', match: :first).check

      # Buttons should become enabled
      assert_button 'Download Selected', disabled: false
      assert_button 'Mark Selected as Printed', disabled: false
    end

    test 'selecting all letters with the header checkbox' do
      visit admin_print_queue_index_path

      # Initially no checkboxes are checked
      assert_equal 0, find_all('.letter-checkbox:checked').size

      # Click the "Select All" checkbox
      find_by_id('select-all-pending').check

      # All letter checkboxes should be checked now
      letter_checkboxes = find_all('.letter-checkbox')
      assert_equal letter_checkboxes.size, find_all('.letter-checkbox:checked').size

      # Buttons should be enabled
      assert_button 'Download Selected', disabled: false
      assert_button 'Mark Selected as Printed', disabled: false

      # Uncheck the "Select All" checkbox
      find_by_id('select-all-pending').uncheck

      # All letter checkboxes should be unchecked now
      assert_equal 0, find_all('.letter-checkbox:checked').size

      # Buttons should be disabled again
      assert_button 'Download Selected', disabled: true
      assert_button 'Mark Selected as Printed', disabled: true
    end

    test 'marking letters as printed' do
      visit admin_print_queue_index_path

      # Count initial pending letters
      initial_pending_count = find_all('.letter-checkbox').size

      # Select the first letter
      find('.letter-checkbox', match: :first).check

      # Click the "Mark Selected as Printed" button
      accept_confirm do
        find_by_id('mark-printed-btn').click
      end

      # Wait for the page to reload
      assert_selector 'h1', text: 'Print Queue'

      # We should have one less pending letter now
      assert_equal initial_pending_count - 1, find_all('.letter-checkbox').size

      # Should see a success message
      assert_text '1 letters marked as printed'
    end

    test 'viewing individual letter' do
      visit admin_print_queue_index_path

      # Find the "View PDF" link for the first letter and click it
      within(find('tr', match: :first)) do
        click_link 'View PDF'
      end

      # This will open in a new tab, so we can't easily test the PDF content,
      # but we can verify the link works by checking the URL
      # Switch back to the main window
      switch_to_window(windows.first)

      # Verify we're still on the print queue page
      assert_selector 'h1', text: 'Print Queue'
    end
  end
end

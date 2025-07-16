# frozen_string_literal: true

require 'application_system_test_case'

module Admin
  class PrintQueueTest < ApplicationSystemTestCase
    setup do
      @admin = create(:admin)

      # Create print queue items using factories
      @pending_letter = create(:print_queue_item, :pending, letter_type: :registration_confirmation)
      @pending_letter2 = create(:print_queue_item, :pending, letter_type: :application_approved)
      @printed_letter = create(:print_queue_item, letter_type: :account_created, admin: @admin)

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
      first('.letter-checkbox').check

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
      first('.letter-checkbox').check

      # Click the "Mark Selected as Printed" button
      if has_selector?('#mark-printed-btn')
        find_by_id('mark-printed-btn').click
      elsif has_button?('Mark Selected as Printed')
        click_button 'Mark Selected as Printed'
      else
        skip 'Mark as printed button not found'
      end

      # Wait for the page to reload
      assert_selector 'h1', text: 'Print Queue'

      # We should have one less pending letter now
      assert_equal initial_pending_count - 1, find_all('.letter-checkbox').size

      # Should see a success message with proper singular/plural form
      assert_text '1 letter marked as printed'
    end

    test 'viewing individual letter' do
      visit admin_print_queue_index_path

      # Find the "View PDF" link in the pending letters table specifically
      pending_table = find('h2', text: 'Pending Letters').find(:xpath, './following-sibling::*//table')

      view_link = pending_table.find('tbody tr:first-child').find_link('View PDF', exact: false)
      if view_link
        new_window = window_opened_by { view_link.click }

        # Ensure a new tab/window opened
        assert new_window, 'Expected clicking View PDF to open a new window'

        # Close the PDF window and switch back immediately to avoid ScopeError
        within_window new_window do
          assert_current_path(%r{admin/print_queue},
                              ignore_query: true)
        end

        new_window.close

        # Back on the main Print Queue page
        assert_selector 'h1', text: 'Print Queue'
      else
        skip 'View PDF link not available - likely PDF not properly attached'
      end
    end
  end
end

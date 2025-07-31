# frozen_string_literal: true

require 'test_helper'

module ConstituentPortal
  class IncomeThresholdControllerTest < ActionDispatch::IntegrationTest
    include AuthenticationTestHelper

    setup do
      # Use factory bot instead of fixture
      @user = create(:constituent)
      sign_in_for_integration_test(@user)

      # Set up FPL policies for testing
      setup_fpl_policies
    end

    test 'fpl_thresholds endpoint returns correct data' do
      get fpl_thresholds_constituent_portal_applications_path
      assert_response :success

      # Parse the JSON response
      json_response = response.parsed_body

      # Verify the response contains the expected data
      assert_equal 400, json_response['modifier']
      assert_equal 15_650, json_response['thresholds']['1']
      assert_equal 21_150, json_response['thresholds']['2']
      assert_equal 26_650, json_response['thresholds']['3']
      assert_equal 32_150, json_response['thresholds']['4']
      assert_equal 37_650, json_response['thresholds']['5']
      assert_equal 43_150, json_response['thresholds']['6']
      assert_equal 48_650, json_response['thresholds']['7']
      assert_equal 54_150, json_response['thresholds']['8']
    end

    test 'income threshold calculation is correct' do
      # This test verifies that the income threshold calculation is correct
      # for different household sizes and income values

      # Get the FPL thresholds from the server
      get fpl_thresholds_constituent_portal_applications_path
      json_response = response.parsed_body

      # Extract the thresholds and modifier
      thresholds = json_response['thresholds']
      modifier = json_response['modifier']

      # Test cases for different household sizes and incomes
      test_cases = [
        { household_size: 1, income: 59_999, expected_result: true },  # Below threshold
        { household_size: 1, income: 62_601, expected_result: false }, # Above threshold (62,600 threshold)
        { household_size: 3, income: 99_999, expected_result: true },  # Below threshold
        { household_size: 3, income: 106_601, expected_result: false }, # Above threshold
        { household_size: 8, income: 216_599, expected_result: true },  # Below threshold
        { household_size: 8, income: 216_601, expected_result: false }, # Above threshold
        { household_size: 10, income: 216_599, expected_result: true },  # Above household size 8, use size 8 threshold
        { household_size: 10, income: 216_601, expected_result: false }  # Above household size 8, use size 8 threshold
      ]

      # Verify each test case
      test_cases.each do |test_case|
        household_size = test_case[:household_size]
        income = test_case[:income]
        expected_result = test_case[:expected_result]

        # Calculate the threshold
        base_fpl = thresholds[household_size.to_s] || thresholds['8'] # Default to size 8 if larger
        threshold = base_fpl * (modifier / 100.0)

        # Check if income is below threshold
        actual_result = income <= threshold

        assert_equal expected_result, actual_result,
                     "Expected income #{income} to be #{expected_result ? 'below' : 'above'} threshold for household size #{household_size}"
      end
    end
  end
end

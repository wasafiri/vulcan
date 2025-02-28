require "test_helper"

module ConstituentPortal
  class IncomeThresholdTest < ActionDispatch::IntegrationTest
    setup do
      @user = users(:constituent_john)
      sign_in(@user)

      # Set up FPL policies for testing
      Policy.find_or_create_by(key: "fpl_1_person").update(value: 15000)
      Policy.find_or_create_by(key: "fpl_2_person").update(value: 20000)
      Policy.find_or_create_by(key: "fpl_3_person").update(value: 25000)
      Policy.find_or_create_by(key: "fpl_4_person").update(value: 30000)
      Policy.find_or_create_by(key: "fpl_5_person").update(value: 35000)
      Policy.find_or_create_by(key: "fpl_6_person").update(value: 40000)
      Policy.find_or_create_by(key: "fpl_7_person").update(value: 45000)
      Policy.find_or_create_by(key: "fpl_8_person").update(value: 50000)
      Policy.find_or_create_by(key: "fpl_modifier_percentage").update(value: 400)
    end

    test "fpl_thresholds endpoint returns correct data" do
      get fpl_thresholds_constituent_portal_applications_path
      assert_response :success

      # Parse the JSON response
      json_response = JSON.parse(response.body)

      # Verify the response contains the expected data
      assert_equal 400, json_response["modifier"]
      assert_equal 15000, json_response["thresholds"]["1"]
      assert_equal 20000, json_response["thresholds"]["2"]
      assert_equal 25000, json_response["thresholds"]["3"]
      assert_equal 30000, json_response["thresholds"]["4"]
      assert_equal 35000, json_response["thresholds"]["5"]
      assert_equal 40000, json_response["thresholds"]["6"]
      assert_equal 45000, json_response["thresholds"]["7"]
      assert_equal 50000, json_response["thresholds"]["8"]
    end

    test "income threshold calculation is correct" do
      # This test verifies that the income threshold calculation is correct
      # for different household sizes and income values

      # Get the FPL thresholds from the server
      get fpl_thresholds_constituent_portal_applications_path
      json_response = JSON.parse(response.body)

      # Extract the thresholds and modifier
      thresholds = json_response["thresholds"]
      modifier = json_response["modifier"]

      # Test cases for different household sizes and incomes
      test_cases = [
        { household_size: 1, income: 59999, expected_result: true },  # Below threshold
        { household_size: 1, income: 60001, expected_result: false }, # Above threshold
        { household_size: 3, income: 99999, expected_result: true },  # Below threshold
        { household_size: 3, income: 100001, expected_result: false }, # Above threshold
        { household_size: 8, income: 199999, expected_result: true },  # Below threshold
        { household_size: 8, income: 200001, expected_result: false }, # Above threshold
        { household_size: 10, income: 199999, expected_result: true },  # Above household size 8, use size 8 threshold
        { household_size: 10, income: 200001, expected_result: false }  # Above household size 8, use size 8 threshold
      ]

      # Verify each test case
      test_cases.each do |test_case|
        household_size = test_case[:household_size]
        income = test_case[:income]
        expected_result = test_case[:expected_result]

        # Calculate the threshold
        base_fpl = thresholds[household_size.to_s] || thresholds["8"] # Default to size 8 if larger
        threshold = base_fpl * (modifier / 100.0)

        # Check if income is below threshold
        actual_result = income <= threshold

        assert_equal expected_result, actual_result,
          "Expected income #{income} to be #{expected_result ? 'below' : 'above'} threshold for household size #{household_size}"
      end
    end

    # The JavaScript test has been moved to test/system/constituent_portal/income_threshold_system_test.rb
  end
end

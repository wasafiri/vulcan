require "test_helper"

class GuardianValidationTest < ActiveSupport::TestCase
  def setup
    @constituent = build(:constituent)
  end

  test "guardian relationship is required when is_guardian is true" do
    @constituent.is_guardian = true
    @constituent.guardian_relationship = nil

    assert_not @constituent.valid?
    assert_includes @constituent.errors[:guardian_relationship], "can't be blank"
  end

  test "guardian relationship is not required when is_guardian is false" do
    @constituent.is_guardian = false
    @constituent.guardian_relationship = nil

    assert @constituent.valid?
  end

  test "guardian relationship can be set to Parent" do
    @constituent.is_guardian = true
    @constituent.guardian_relationship = "Parent"

    assert @constituent.valid?
  end

  test "guardian relationship can be set to Legal Guardian" do
    @constituent.is_guardian = true
    @constituent.guardian_relationship = "Legal Guardian"

    assert @constituent.valid?
  end
end

# frozen_string_literal: true

require 'test_helper'

class VoucherTest < ActiveSupport::TestCase
  setup do
    @application = create(:application)
    @voucher = create(:voucher, application: @application)
  end

  test 'valid voucher' do
    assert @voucher.valid?
  end

  test 'requires application' do
    @voucher.application = nil
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:application], 'must exist'
  end

  test 'requires code' do
    @voucher.code = nil
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:code], "can't be blank"
  end

  test 'requires unique code' do
    duplicate = build(:voucher, code: @voucher.code)
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], 'has already been taken'
  end

  test 'requires initial value' do
    @voucher.initial_value = nil
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:initial_value], "can't be blank"
  end

  test 'requires non-negative initial value' do
    @voucher.initial_value = -100
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:initial_value], 'must be greater than or equal to 0'
  end

  test 'requires remaining value' do
    @voucher.remaining_value = nil
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:remaining_value], "can't be blank"
  end

  test 'requires non-negative remaining value' do
    @voucher.remaining_value = -50
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:remaining_value], 'must be greater than or equal to 0'
  end

  test 'remaining value cannot exceed initial value' do
    @voucher.initial_value = 100
    @voucher.remaining_value = 150
    assert_not @voucher.valid?
    assert_includes @voucher.errors[:remaining_value], 'cannot exceed initial value'
  end

  test 'generates unique code on create' do
    voucher = build(:voucher, code: nil)
    assert voucher.save
    assert_match(/\A[A-Z0-9]{12}\z/, voucher.code)
  end

  test 'calculates initial values based on disabilities' do
    # Set policy values for disabilities
    Policy.set('voucher_value_hearing_disability', 100)
    Policy.set('voucher_value_vision_disability', 200)
    Policy.set('voucher_value_mobility_disability', 300)
    Policy.set('voucher_value_speech_disability', 400)
    Policy.set('voucher_value_cognition_disability', 500)

    # Create constituent with specific disabilities
    constituent = create(:constituent,
                         hearing_disability: true,   # 100
                         vision_disability: true,    # 200
                         mobility_disability: false, # 0
                         speech_disability: false,   # 0
                         cognition_disability: false) # 0
    application = create(:application, user: constituent)

    # Debug disability values
    puts "Hearing: #{constituent.hearing_disability.inspect}, #{constituent.hearing_disability.class}, #{Policy.voucher_value_for_disability('hearing')}"
    puts "Vision: #{constituent.vision_disability.inspect}, #{constituent.vision_disability.class}, #{Policy.voucher_value_for_disability('vision')}"
    puts "Mobility: #{constituent.mobility_disability.inspect}, #{constituent.mobility_disability.class}, #{Policy.voucher_value_for_disability('mobility')}"
    puts "Speech: #{constituent.speech_disability.inspect}, #{constituent.speech_disability.class}, #{Policy.voucher_value_for_disability('speech')}"
    puts "Cognition: #{constituent.cognition_disability.inspect}, #{constituent.cognition_disability.class}, #{Policy.voucher_value_for_disability('cognition')}"

    # Debug the calculation
    puts 'Calculation:'
    total = 0
    Constituent::DISABILITY_TYPES.each do |disability_type|
      value = constituent.send("#{disability_type}_disability")
      disability_value = value == true ? Policy.voucher_value_for_disability(disability_type) : 0
      total += disability_value
      puts "  #{disability_type}: #{value.inspect}, #{disability_value}"
    end
    puts "  Total: #{total}"

    # Debug the model's calculation
    model_total = Voucher.calculate_value_for_constituent(constituent)
    puts "  Model total: #{model_total}"

    voucher = build(:voucher, application: application, initial_value: nil, remaining_value: nil)
    assert voucher.save

    # Debug calculated value
    puts "Initial value: #{voucher.initial_value.inspect}"
    puts "Initial value class: #{voucher.initial_value.class}"

    assert_equal 300, voucher.initial_value # 100 + 200
    assert_equal voucher.initial_value, voucher.remaining_value
    assert_not_nil voucher.issued_at
  end

  test 'sends notification when assigned' do
    assert_enqueued_email_with VoucherNotificationsMailer, :voucher_assigned do
      create(:voucher)
    end
  end

  test 'creates event when assigned' do
    Current.user = create(:admin)
    application = create(:application, status: :approved)
    application.update!(medical_certification_status: :accepted)

    assert_difference -> { Event.where(action: 'voucher_assigned').count }, 1 do
      application.assign_voucher!
    end

    event = Event.where(action: 'voucher_assigned').last
    assert_equal application.id, event.metadata['application_id']
    assert_not_nil event.metadata['voucher_code']
    assert_not_nil event.metadata['initial_value']
    assert_not_nil event.metadata['timestamp']
  end

  test 'can be redeemed when active' do
    @voucher.update!(status: :active)
    assert @voucher.can_redeem?(50)
  end

  test 'cannot be redeemed when not active' do
    @voucher.update!(status: :issued)
    assert_not @voucher.can_redeem?(50)
  end

  test 'cannot be redeemed for more than remaining value' do
    @voucher.update!(
      status: :active,
      remaining_value: 100
    )
    assert_not @voucher.can_redeem?(150)
  end

  test 'cannot be redeemed when expired' do
    @voucher.update!(
      status: :active,
      issued_at: 7.months.ago
    )
    assert_not @voucher.can_redeem?(50)
  end

  test 'successful redemption creates transaction and updates status' do
    vendor = create(:vendor)
    @voucher.update!(
      status: :active,
      initial_value: 100,
      remaining_value: 100
    )

    assert_difference -> { @voucher.transactions.count }, 1 do
      @voucher.redeem!(75, vendor)
    end

    assert_equal 25, @voucher.remaining_value
    assert_equal vendor, @voucher.vendor
    assert_not_nil @voucher.last_used_at
  end

  test 'full redemption marks voucher as redeemed' do
    vendor = create(:vendor)
    @voucher.update!(
      status: :active,
      initial_value: 100,
      remaining_value: 100
    )

    @voucher.redeem!(100, vendor)
    assert @voucher.voucher_redeemed?
  end

  test 'sends notification when redeemed' do
    vendor = create(:vendor)
    @voucher.update!(
      status: :active,
      initial_value: 100,
      remaining_value: 100
    )

    assert_enqueued_email_with VoucherNotificationsMailer, :voucher_redeemed do
      @voucher.redeem!(100, vendor)
    end
  end

  test 'can be cancelled when issued' do
    @voucher.update!(status: :issued)
    assert @voucher.can_cancel?
  end

  test 'can be cancelled when active' do
    @voucher.update!(status: :active)
    assert @voucher.can_cancel?
  end

  test 'cannot be cancelled when redeemed' do
    @voucher.update!(status: :redeemed)
    assert_not @voucher.can_cancel?
  end

  test 'successful cancellation updates status and notes' do
    @voucher.update!(status: :active)
    freeze_time do
      @voucher.cancel!
      assert @voucher.voucher_cancelled?
      assert_includes @voucher.notes, "Cancelled at #{Time.current}"
    end
  end

  test 'sends notification when expired' do
    assert_enqueued_email_with VoucherNotificationsMailer, :voucher_expired do
      @voucher.update!(status: :expired)
    end
  end
end

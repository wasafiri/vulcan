# frozen_string_literal: true

module FlashTestHelper
  # Assert that a flash message of the given type exists with the given content
  def assert_flash_message(type, content)
    assert_equal content, flash[type.to_sym],
      "Expected flash[:#{type}] to be '#{content}', but was '#{flash[type.to_sym]}'"
  end

  # Assert that a flash message of the given type exists with the given content after following a redirect
  def assert_flash_message_after_redirect(type, content)
    follow_redirect!
    assert_flash_message(type, content)
  end

  # Assert that a flash message of the given type contains the given content (partial match)
  def assert_flash_message_includes(type, content)
    assert flash[type.to_sym].to_s.include?(content),
      "Expected flash[:#{type}] to include '#{content}', but was '#{flash[type.to_sym]}'"
  end

  # Assert that a flash message of the given type contains the given content after following a redirect
  def assert_flash_message_includes_after_redirect(type, content)
    follow_redirect!
    assert_flash_message_includes(type, content)
  end

  # Assert that a flash message of the given type matches the given pattern
  def assert_flash_message_matches(type, pattern)
    assert_match pattern, flash[type.to_sym].to_s,
      "Expected flash[:#{type}] to match #{pattern}, but was '#{flash[type.to_sym]}'"
  end

  # Assert that a flash message of the given type matches the given pattern after following a redirect
  def assert_flash_message_matches_after_redirect(type, pattern)
    follow_redirect!
    assert_flash_message_matches(type, pattern)
  end

  # Assert that a flash message of the given type exists
  def assert_flash_message_exists(type)
    assert flash[type.to_sym].present?,
      "Expected flash[:#{type}] to exist, but it was blank or nil"
  end

  # Assert that a flash message of the given type exists after following a redirect
  def assert_flash_message_exists_after_redirect(type)
    follow_redirect!
    assert_flash_message_exists(type)
  end

  # Assert that a flash message of the given type does not exist
  def assert_flash_message_not_exists(type)
    assert flash[type.to_sym].blank?,
      "Expected flash[:#{type}] not to exist, but it was '#{flash[type.to_sym]}'"
  end

  # Assert that a flash message of the given type does not exist after following a redirect
  def assert_flash_message_not_exists_after_redirect(type)
    follow_redirect!
    assert_flash_message_not_exists(type)
  end
end

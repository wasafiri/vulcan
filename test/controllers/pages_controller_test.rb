# frozen_string_literal: true

require 'test_helper'

class PagesControllerTest < ActionDispatch::IntegrationTest
  def test_should_get_how_it_works
    get how_it_works_path
    assert_response :success
  end

  def test_should_get_help
    get help_path
    assert_response :success
  end

  def test_should_get_contact
    get contact_path
    assert_response :success
  end

  def test_should_get_apply
    get apply_path
    assert_response :success
  end

  def test_should_get_eligibility
    get eligibility_path
    assert_response :success
  end
end

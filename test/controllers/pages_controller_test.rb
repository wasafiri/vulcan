require "test_helper"

describe PagesController do
  it "gets help" do
    get pages_help_url
    must_respond_with :success
  end

  it "gets how_it_works" do
    get pages_how_it_works_url
    must_respond_with :success
  end

  it "gets eligibility" do
    get pages_eligibility_url
    must_respond_with :success
  end

  it "gets apply" do
    get pages_apply_url
    must_respond_with :success
  end

  it "gets contact" do
    get pages_contact_url
    must_respond_with :success
  end
end

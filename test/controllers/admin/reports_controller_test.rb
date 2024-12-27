require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
 setup do
   @admin = users(:admin)
   sign_in_as(@admin)
 end
end

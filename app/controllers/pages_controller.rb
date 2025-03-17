class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: %i[help how_it_works eligibility apply contact privacy terms accessibility]

  def help; end

  def how_it_works; end

  def eligibility; end

  def apply; end

  def contact; end
end

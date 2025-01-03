class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: [
    :help, :how_it_works, :eligibility, :apply, :contact
  ]

  def help
  end

  def how_it_works
  end

  def eligibility
  end

  def apply
  end

  def contact
  end
end

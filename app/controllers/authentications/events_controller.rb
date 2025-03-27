# frozen_string_literal: true

module Authentications
  class EventsController < ApplicationController
    def index
      @events = Current.user.events.order(created_at: :desc)
    end
  end
end

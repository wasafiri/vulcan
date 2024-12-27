class Admin::ApplicationsController < ApplicationController
  before_action :set_application, only: [ :show, :edit, :update ]
  def index
  end

  def show
  end

  def edit
  end

  def update
  end

  def search
  end

  def filter
  end

  def batch_approve
  end

  def batch_reject
  end

  def verify_income
  end

  def request_documents
  end

  private

  def set_application
    @application = Application.find(params[:id])
  end
end

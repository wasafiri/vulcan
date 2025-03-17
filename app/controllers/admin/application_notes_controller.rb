class Admin::ApplicationNotesController < Admin::BaseController
  before_action :set_application

  def create
    @note = @application.application_notes.new(note_params)
    @note.admin = current_user

    if @note.save
      redirect_to admin_application_path(@application), notice: 'Note added successfully.'
    else
      redirect_to admin_application_path(@application), alert: "Failed to add note: #{@note.errors.full_messages.join(', ')}"
    end
  end

  private

  def set_application
    @application = Application.find(params[:application_id])
  end

  def note_params
    params.require(:application_note).permit(:content, :internal_only)
  end
end

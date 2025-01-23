module Admin::ApplicationsHelper
  def toggle_direction(column)
    if params[:sort] == column
      params[:direction] == "asc" ? "desc" : "asc"
    else
      "asc"
    end
  end
end

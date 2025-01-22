module FormComponentHelper
  def error_field_class(form, field)
    form.object.errors[field].present? ? "border-red-500" : "border-gray-300"
  end

  def form_section(title:, &block)
    tag.div(class: "form-section") do
      concat tag.h3(title, class: "text-lg font-medium mb-4")
      concat capture(&block)
    end
  end
end

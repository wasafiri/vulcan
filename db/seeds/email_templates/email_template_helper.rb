module EmailTemplateHelper
  def self.template_path(mailer_name, template_name)
    Rails.root.join('app', 'views', mailer_name, "#{template_name}.text.erb")
  end

  def self.read_template(mailer_name, template_name)
    path = template_path(mailer_name, template_name)
    File.exist?(path) ? File.read(path) : nil
  end

  def self.convert_erb_to_placeholders(erb_content)
    return nil if erb_content.nil?

    text = erb_content.dup

    # Remove any render partials
    text.gsub!(/<%=\s*render.*?%>/, '')

    # Replace object.attribute accesses: e.g. <%= object.attribute %> => %{object_attribute}
    text.gsub!(/<%=\s*(\w+)\.(\w+)\s*%>/, '%{\1_\2}')

    # Replace instance variables: <%= @var %> => %{var}
    text.gsub!(/<%=\s*@(\w+)\s*%>/, '%{\1}')

    # Replace direct interpolation: <%= var %> => %{var}
    text.gsub!(/<%=\s*(\w+)\s*%>/, '%{\1}')

    # Remove ERB comments
    text.gsub!(/<%#.*?%>/, '')

    # Remove simple ERB logic tags (if, unless, end, each)
    text.gsub!(/<%\s*(if|unless|end|each).*?%>/, '')

    # Collapse excessive newlines
    text.gsub!(/\n{3,}/, "\n\n")

    text.strip
  end
end

class AddWebsiteUrlToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :website_url, :string
  end
end

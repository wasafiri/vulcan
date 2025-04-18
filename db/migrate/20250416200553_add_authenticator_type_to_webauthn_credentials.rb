class AddAuthenticatorTypeToWebauthnCredentials < ActiveRecord::Migration[8.0]
  def change
    add_column :webauthn_credentials, :authenticator_type, :string
  end
end

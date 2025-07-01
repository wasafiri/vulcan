# frozen_string_literal: true

# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path

# Add the builds directory to asset paths for esbuild/tailwind compiled assets
Rails.application.config.assets.paths << Rails.root.join('app/assets/builds')

# Precompile additional assets.
Rails.application.config.assets.precompile += %w[application.css application.js]

# Ensure assets can be found in CI environment
if Rails.env.test? && ENV['CI'].present?
  # Make sure Rails knows about our compiled assets
  Rails.application.config.assets.unknown_asset_fallback = false
  Rails.application.config.assets.raise_runtime_errors = true
end

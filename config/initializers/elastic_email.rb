ElasticEmail.configure do |config|
  config.api_key['apikey'] = ENV['ELASTIC_EMAIL_API_KEY']
end

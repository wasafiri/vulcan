# Active Storage S3 Setup

This document provides instructions for setting up Active Storage with Amazon S3 using either Bucketeer or direct S3 credentials.

## Configuration

The application has been configured to use S3 for file storage in production and optionally in development. This setup provides flexibility to work with either the Bucketeer Heroku add-on or direct AWS S3 credentials.

### Environment Variables

The following environment variables can be used to configure S3:

#### Direct S3 Configuration
```
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
S3_REGION=us-east-1
S3_BUCKET=your-bucket-name
```

#### Bucketeer Configuration (Set automatically by the Bucketeer add-on)
```
BUCKETEER_AWS_ACCESS_KEY_ID=bucketeer_provided_key
BUCKETEER_AWS_SECRET_ACCESS_KEY=bucketeer_provided_secret
BUCKETEER_AWS_REGION=bucketeer_region
BUCKETEER_BUCKET_NAME=bucketeer_bucket
```

#### Development Options
```
USE_S3=true  # Set to use S3 in development environment (optional)
```

## How It Works

The `config/storage.yml` file contains a flexible S3 configuration that checks for both direct S3 and Bucketeer environment variables:

```yaml
s3:
  service: S3
  access_key_id: <%= ENV['S3_ACCESS_KEY_ID'] || ENV['BUCKETEER_AWS_ACCESS_KEY_ID'] %>
  secret_access_key: <%= ENV['S3_SECRET_ACCESS_KEY'] || ENV['BUCKETEER_AWS_SECRET_ACCESS_KEY'] %>
  region: <%= ENV['S3_REGION'] || ENV['BUCKETEER_AWS_REGION'] || 'us-east-1' %>
  bucket: <%= ENV['S3_BUCKET'] || ENV['BUCKETEER_BUCKET_NAME'] %>
```

The `config/initializers/storage.rb` file sets the Active Storage service based on the environment:

```ruby
Rails.application.config.to_prepare do
  Rails.application.config.active_storage.service = 
    case Rails.env
    when 'test'
      :test
    when 'development'
      ENV['USE_S3'] == 'true' ? :s3 : :local
    else
      :s3
    end
end
```

## Deployment Options

### Heroku with Bucketeer

1. Install the Bucketeer add-on:

```
heroku addons:create bucketeer:hobbyist
```

2. No additional configuration is needed as Bucketeer will automatically set the necessary environment variables.

3. The setup is already configured to use S3 in production. Production environment settings are explicitly set in:
   - config/environments/production.rb: `config.active_storage.service = :s3`
   - config/initializers/storage.rb: Environment-based configuration

### Heroku without Bucketeer or Other Hosting Platforms

Set the required environment variables:

```
S3_ACCESS_KEY_ID=your_access_key
S3_SECRET_ACCESS_KEY=your_secret_key
S3_REGION=us-east-1
S3_BUCKET=your-bucket-name
```

### Local Development

To use S3 in development:

1. Copy `.env.example` to `.env`
2. Fill in your S3 credentials
3. Set `USE_S3=true`
4. Load the environment variables (depending on your setup, you might use `dotenv` or similar)

## Verifying Configuration

To verify your S3 configuration is working correctly:

1. Upload a file using Active Storage
2. Check if the file is accessible
3. Look for any errors in the Rails logs

## Switching Storage Services

The code is designed to make it easy to switch between storage services:

- To change from Bucketeer to direct S3: Simply set the S3_* environment variables
- To switch to a different storage service: Update the storage.yml file and the storage.rb initializer

source "https://rubygems.org"

gem "rails", "~> 8.1.3", ">= 8.1.3.1"
gem "propshaft"
gem "pg", "~> 1.5"
gem "puma", ">= 5.0"
gem "vite_rails"
gem "multipart-post"
gem "countries", "~> 8.1"
gem "aws-sdk-s3", require: false
gem "tzinfo-data"
gem "solid_queue"
gem "rack-attack", "~> 6.8"
gem "bootsnap", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "bundler-audit", require: false
  gem "brakeman", require: false
  gem "rubocop-rails-omakase", require: false
end

group :development do
  gem "web-console"
end

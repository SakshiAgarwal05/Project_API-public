source 'https://rubygems.org'
git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end
gem 'rails', '~> 5.1.6.2'
gem 'activerecord-import'
gem 'pg', '~> 0.21.0', platforms: [:mri, :mingw, :x64_mingw]
gem 'mysql2'
gem 'cequel'
gem 'puma', '~> 3.7'
gem 'jbuilder', '~> 2.5'
gem 'oj'
gem 'nokogiri'
gem 'kaminari' #Remove this after replace by `pagy`
gem 'pagy'
gem 'elasticsearch-model', github: 'elastic/elasticsearch-rails'
gem 'elasticsearch-rails', github: 'elastic/elasticsearch-rails'
gem 'aasm', '4.12.3'
gem 'activesupport', '~> 5.1.6.2'
gem 'devise', '4.6.0'
gem 'bcrypt', '~> 3.1.11', platforms: :ruby
gem 'omniauth', '1.9.0'
gem 'omniauth-linkedin', '0.2.0'
gem 'seed_dump' # , '3.2.4'
gem 'cancancan', '2.1.2'
gem "paranoia", "~> 2.2" # , github: "rubysherpas/paranoia", branch: "rails5"
gem 'embedson', '1.1.0'
gem "sprockets", ">= 3.7.2"
gem 'httparty', '0.15.6'
gem 'sdoc', '~> 1.0.0', group: :doc
gem 'phone'
gem 'icalendar'
gem 'to_jbuilder'
# Not sure which one we are using
gem 'linkedin-oauth2', '~> 1.0'
gem 'jwt', '~> 2.1.0'
gem 'figaro'
gem 'unf'
gem 'whenever', :require => false
gem 'unicorn', platforms: [:mri]
gem 'public_suffix'
gem 'm2m_fast_insert', '~> 0.4.0', github: "suratpyari/m2m_fast_insert"
source "https://gems.contribsys.com/" do
  gem 'sidekiq-pro', '3.5.3'
end
gem 'sidekiq-scheduler', '2.1.10'
gem 'sidekiq', '5.0.5'
gem 'sidekiq-status', '0.7.0'
gem 'sinatra'
gem 'jquery-ui-rails'
gem 'active_job_status'
gem 'pusher'
gem 'redis'
gem 'redis-namespace'
gem 'redis-rails'
gem 'redis-rack-cache', ">= 2.0.2"
gem "redis-store", ">= 1.4.0"
gem 'aws-sdk', '3.0.1'
gem 'browser'
gem 'wicked_pdf'
gem 'wkhtmltopdf-binary'
gem 'responders'
gem 'htmltoword'
gem "mini_magick"
gem "retries"
gem 'chronic'
gem 'rubyzip', ">= 1.2.2"
gem "loofah", ">= 2.2.3"
gem "mustache", "~> 1.0"
gem 'json', "~> 2.0.4"
# gem 'scout_apm', '~> 2.4.24'
gem 'scout_apm', '~> 2.6.6'
gem 'rufus-scheduler', '~>3.4.2'
gem 'connection_pool'
gem 'aws-sdk-sqs', '~> 1.16.0'
gem 'pghero'
gem 'pg_query', '>= 0.9.0'
gem 'hashdiff', '~> 1.0.0'
gem 'rack-attack'
gem 'colorize'
gem 'logstasher'
gem 'logstash-logger'

group :development, :test do
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw], require: !ENV['RM_INFO']
  gem 'pry-byebug', platforms: [:mri, :mingw, :x64_mingw], require: !ENV['RM_INFO']
  gem 'awesome_print' # https://github.com/awesome-print/awesome_print/blob/master/LICENSE
  gem 'pry-rails', '~> 0.3.6', require: !!ENV['RAILS_USE_PRY']
  gem 'rubocop-airbnb'
  gem "lol_dba"
  gem 'pronto'
  gem 'pronto-rubocop', require: false
  gem 'pronto-flay', require: false
end

group :development do
  gem 'capistrano'
  gem 'capistrano-rails'
  gem 'capistrano-rvm'
  gem 'capistrano-rbenv'
  gem 'capistrano-secrets-yml', '~> 1.0.0'
  gem 'capistrano3-unicorn'
  gem 'capistrano-upload-config'
  gem 'bullet'
  gem 'rails_best_practices'
  gem 'rack-mini-profiler', require: false
  gem 'rubycritic'
  gem 'brakeman', :require => false
  gem 'web-console', '>= 3.3.0'
  gem 'listen', '>= 3.0.5', '< 3.2'
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0.0'
  gem 'meta_request'
  gem 'active_record_doctor'
end
group :test do
  gem 'faker'
  gem 'rspec-rails'
  gem 'database_cleaner'
  gem 'simplecov', '~> 0.18', :require => false
  gem 'simplecov-lcov', :require => false
  gem 'simplecov-html', :require => false
  gem 'simplecov-console', :require => false
  gem 'simplecov-cobertura', :require => false
  gem 'factory_bot_rails', :require => false
  gem 'rspec-activemodel-mocks'
  gem 'shoulda-matchers', '~> 3.1'
  gem 'rails-controller-testing'
  gem 'rspec_junit_formatter'
  gem 'webmock'
  gem 'rspec-kickstarter'
end
gem 'state_machine', '1.2.0'
gem 'geocoder', '1.4.4'

# Added at 2018-01-23 13:36:51 -0500 by ecoutu:
gem "rollbar", "~> 2.15"

# Added at 2018-03-14 13:17:32 -0400 by ecoutu:
gem "lograge", "~> 0.9.0"

# Added at 2018-03-19 14:13:04 -0400 by ecoutu:
gem "request_store", "~> 1.4"

# Added at 2018-03-20 14:00:16 -0400 by ecoutu:
gem "addressable", "~> 2.5"

gem "parallel_tests", "~> 2.25", :groups => [:development, :test]

# https://github.com/ankane/groupdate
gem 'groupdate'

gem "prometheus-client-mmap", "~> 0.9.10"
gem "yabeda-rails", "~> 0.1.3"
gem "yabeda-sidekiq", "~> 0.1.4"
gem "yabeda-prometheus", "~> 0.1.5"
gem "yabeda-puma-plugin", "~> 0.1.0"

gem 'time_difference', '~> 0.7.0'

gem 'impressionist', '~>1.6.1'

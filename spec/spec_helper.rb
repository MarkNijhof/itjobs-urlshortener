require File.join(File.dirname(__FILE__), '..', 'url_shortener.rb')

require 'rubygems'
require 'sinatra'
require 'rack/test'
require 'rspec'
require 'rspec/autorun'

# require 'capybara'
# require 'capybara/dsl'
require 'capybara/rspec'

# set test environment
set :environment, :test
set :run, false
set :raise_errors, true
set :logging, false


RSpec.configure do |config|
  Capybara.app = UrlShortener
  Capybara.default_driver = :selenium
  Capybara.default_wait_time = 5
  
  config.mock_with :rspec
  config.include Capybara
  
  config.before(:each, :redis => true) do
    uri = URI.parse(ENV["REDISTOGO_URL"])
    REDIS ||= Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
    REDIS.flushall
  end
end
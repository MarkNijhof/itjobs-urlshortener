require 'rubygems'
require 'firefly'

disable :run

app = Firefly::Server.new do

  dir = File.dirname(__FILE__)

  set :views, "#{dir}/views"
  set :public, "#{dir}/public"
    
  set :hostname,    "itjo.bs"
  set :api_key,     ""

  # Use Sqlite3 by default
  # set :database,    "sqlite3://#{Dir.pwd}/firefly.sqlite3"

  # Set number of recent urls to show
  set :recent_urls, 10

  # You can use MySQL as well. 
  # Make sure to install the do_mysql gem:
  #    sudo gem install do_mysql
  set :database,    ENV['DATABASE_URL']

  # If you want to enable 'share to twitter'

  # A secure key to be used with 'share to twitter'
  # set :sharing_key,    "set-a-long-secure-key-here"
  set :sharing_key,      ""

  # Currently only twitter is supported
  # set :sharing_targets, [:twitter, :hyves, :facebook]
  set :sharing_targets, []

  # Set the TLDs (in URLs) that are allowed to be shortened
  # set :sharing_domains, ["example.com", "mydomain.com"]
  set :sharing_domain, []

  # Set your session secret here.
  # If you're unsure what to use, open IRB console and run `'%x' % rand(2**255)`
  set :session_secret, "9c9e4f86c5b37ccb16b6eb32445c418ac6a0c9268a60742e20edfd88668db90"
end

run app

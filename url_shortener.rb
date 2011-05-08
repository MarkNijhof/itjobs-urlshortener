require 'rubygems'
require 'sinatra'
require 'redis'
require 'uri'
require 'json'
require 'json/ext'

require 'sinatra/base'

class UrlShortener < Sinatra::Base

  set :root, File.dirname(__FILE__)

  configure do
    uri = URI.parse(ENV["REDISTOGO_URL"])
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  get '/' do 
    @original_url = params[:original_url] unless params[:original_url].nil?
    @urls_shortened = REDIS.get("counter:urls_shortened")
    @urls_expanded  = REDIS.get("counter:urls_expanded")
    haml :index 
  end

  post '/' do
    @urls_shortened = REDIS.incr("counter:urls_shortened")
    @urls_expanded  = REDIS.get("counter:urls_expanded")
    short_url = @urls_shortened.to_s(36)
    
    @shortener = {
      'original_url' => params[:original_url],
      'short_url' => short_url,
      'create_date' => Time.new.inspect
    }
  
    save_result = REDIS.set("short_url:#{short_url}", @shortener.to_json)
    raise "Unable to save the short URL" unless save_result == "OK"

    haml :index
  end

  get '/:short_url' do 
    shortner_json = REDIS.get("short_url:#{params[:short_url]}")
    raise "URL has not been shorted" if shortner_json.nil?

    REDIS.incr("counter:short_url:#{params[:short_url]}")
    REDIS.incr("counter:urls_expanded")
    redirect JSON.parse(shortner_json)["original_url"]
  end

  get '/:short_url/inspect' do 
    shortner_json = REDIS.get("short_url:#{params[:short_url]}")
    raise "URL has not been shorted" if shortner_json.nil?
  
    @shortener         = JSON.parse(shortner_json)
    @shortened_counter = REDIS.get("counter:short_url:#{params[:short_url]}") || 0
    @urls_shortened    = REDIS.get("counter:urls_shortened")
    @urls_expanded     = REDIS.get("counter:urls_expanded")
    haml :index
  end

  error do 
    @original_url = params[:original_url] unless params[:original_url].nil?
    haml :index 
  end
end

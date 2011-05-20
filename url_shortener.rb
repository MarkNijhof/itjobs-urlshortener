require 'rubygems'
require 'sinatra'
require 'haml'
require 'redis'
require 'uri'
require 'net/http'
require 'ipaddress'
require 'json'
require 'json/ext'

require 'sinatra/base'

require './pretty_date'

Time.send :include, PrettyDate

class UrlShortener < Sinatra::Base

  set :root, File.dirname(__FILE__)
  
  :escape_html 
  
  configure do
    uri = URI.parse(ENV["REDISTOGO_URL"])
    REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
  end

  get '/' do 
    @server_name = request.env['SERVER_NAME']
    @original_url = params[:original_url] unless params[:original_url].nil?
    @urls_shortened = REDIS.get("counter:urls_shortened")
    @urls_expanded  = REDIS.get("counter:urls_expanded")
    haml :index 
  end

  post '/' do
    content_type :json
    begin
      short_url = REDIS.incr("counter:urls_shortened").to_s(36)
    
      shortener = {
        'original_url' => params[:original_url],
        'short_url' => "http://#{request.env['SERVER_NAME']}/#{short_url}",
        'create_date' => Time.new.inspect
      }.to_json
  
      save_result = REDIS.set("short_url:#{short_url}", shortener)
      raise "Unable to save the short URL" unless save_result == "OK"
      
      shortener
    rescue
      { "error" => "Unable to save the short URL" }.to_json
    end
  end

  get '/:short_url/inspect' do 
    @server_name = request.env['SERVER_NAME']
    shortner_json = REDIS.get("short_url:#{params[:short_url]}")
    raise "URL '/#{params[:short_url]}' has not been shorted" if shortner_json.nil?
  
    @short_url         = params[:short_url]
    @shortener         = JSON.parse(shortner_json)
    @create_date       = Time.parse(@shortener['create_date']).to_pretty
    @original_url      = @shortener['original_url']
    @expanded_counter  = REDIS.get("counter:short_url:#{params[:short_url]}") || 0
    @urls_shortened    = REDIS.get("counter:urls_shortened")
    @urls_expanded     = REDIS.get("counter:urls_expanded")
    haml :index
  end

  get '/:short_url/inspect/countries' do 
    content_type :json
    response['Cache-Control'] = "public, max-age=5"

    expanded_counter  = REDIS.get("counter:short_url:#{params[:short_url]}").to_i || 0
    countries = REDIS.smembers("list:country:short_url:#{params[:short_url]}").to_a
    {}.to_json and return if countries.length == 0
    
    keys = countries.map { |country| "counter:country:short_url:#{params[:short_url]}:#{country}" }
    counters = REDIS.mget(*keys)
    result = Hash[countries.zip(counters.map { |counter| { 'percentage' => (counter.to_i / (expanded_counter.to_f / 100)).round(1), 'value' => counter.to_i } })]

    result['unknown'] = result.delete('xx') if result.include?('xx')
    result['unknown'] = { 'percentage' => 0, 'value' => 0 } unless result.include?('xx')

    total_percentage = 0
    result.each do |key, item| 
      next if key == 'unknown'
      total_percentage = total_percentage + item['percentage'] 
    end
    result['unknown']['percentage'] = (100 - total_percentage).round(1)

    result.delete('unknown') if result['unknown']['percentage'] == 0

    result.to_json
  end

  get '/:short_url/inspect/referrers' do 
    content_type :json
    response['Cache-Control'] = "public, max-age=5"

    expanded_counter  = REDIS.get("counter:short_url:#{params[:short_url]}").to_i || 0
    referrers = REDIS.smembers("list:referrers:short_url:#{params[:short_url]}").to_a
    {}.to_json and return if referrers.length == 0
  
    keys = referrers.map { |referrer| "counter:referrers:short_url:#{params[:short_url]}:#{referrer}" }
    counters = REDIS.mget(*keys)
    result = Hash[referrers.zip(counters.map { |counter| { 'percentage' => (counter.to_i / (expanded_counter.to_f / 100)).round(1), 'value' => counter.to_i } })]

    result['direct'] = result.delete('unknown') if result.include?('unknown')
    result['direct'] = { 'percentage' => 0, 'value' => 0 } unless result.include?('direct')

    total_percentage = 0
    result.each do |key, item| 
      next if key == 'direct'
      total_percentage = total_percentage + item['percentage'] 
    end
    result['direct']['percentage'] = (100 - total_percentage).round(1)

    result.delete('unknown') if result['unknown']['percentage'] == 0

    result.to_json
  end

  get '/:short_url/inspect/minutes' do 
    content_type :json
    response['Cache-Control'] = "public, max-age=5"

    minutes = REDIS.smembers("list:time-in-minutes:short_url:#{params[:short_url]}").to_a
    {}.to_json and return if minutes.length == 0
    keys = minutes.map { |minute| "counter:time-in-minutes:short_url:#{params[:short_url]}:#{minute}" }
    counters = REDIS.mget(*keys).map{ |counter| counter.to_i }
    result = Hash[minutes.map{ |time| Time.at(time.to_i * 60) }.zip(counters)]

    stats = Hash.new
    (minutes[0].to_i..minutes[result.length - 1].to_i).each{ |minute| stats[Time.at(minute * 60)] = 0 }
    stats.merge! result
      
    {'start_date' => Time.at(stats.keys[0]).strftime("%s").to_i * 1000, 'data' => stats.values }.to_json
  end

  get '/*' do 
    redirect "/#{params[:splat][0][0, params[:splat][0].length - 1]}/inspect" and return if params[:splat][0][-1, 1] == " "
    
    short_url = params[:splat][0]
    shortner_json = REDIS.get("short_url:#{short_url}")
    raise "URL '/#{short_url}' has not been shorted" if shortner_json.nil?

    REDIS.multi do
      REDIS.incr("counter:short_url:#{short_url}")
      REDIS.incr("counter:urls_expanded")

      time_in_minutes = (Time.new.utc.strftime("%s").to_i / 60).to_i
      REDIS.sadd("list:time-in-minutes:short_url:#{short_url}", time_in_minutes)
      REDIS.incr("counter:time-in-minutes:short_url:#{short_url}:#{time_in_minutes}")

      referrer = (request.env['HTTP_REFERER'] || 'unknown').downcase
      referrer = referrer[0, referrer.length - 1] if referrer[-1, 1] == '/'
      REDIS.sadd("list:referrers:short_url:#{short_url}", referrer)
      REDIS.incr("counter:referrers:short_url:#{short_url}:#{referrer}")

      country = 'xx'
      ip_address = nil
      ip_addresses = []
      ip_addresses.concat request.env['HTTP_X_FORWARDED_FOR'].split(',') unless request.env['HTTP_X_FORWARDED_FOR'].nil?
      ip_addresses.concat request.env['HTTP_CLIENT_IP'].split(',') unless request.env['HTTP_CLIENT_IP'].nil?
      ip_addresses.concat request.env['REMOTE_ADDR'].split(',') unless request.env['REMOTE_ADDR'].nil?
      ip_addresses.each { |address| ip_address = address and break if IPAddress.valid? address }

      if !ip_address.nil?
        http = Net::HTTP.new('geoip3.maxmind.com', 80)
        http.use_ssl = false
        path = '/a'

        data = "l=#{ENV['MAX_MIND']}&i=#{ip_address}"
        headers = {
          'Referer' => "http://#{ENV['HOSTNAME']}/",
          'Content-Type' => 'application/x-www-form-urlencoded'
        }
        resp, data = http.post(path, data, headers)
        country = data.downcase unless data.include? 'IP_NOT_FOUND'
        REDIS.sadd("list:country:ip-not-found", ip_address) if data.include? 'IP_NOT_FOUND'
      end
      
      REDIS.sadd("list:country:short_url:#{short_url}", country)
      REDIS.incr("counter:country:short_url:#{short_url}:#{country}")
    end
    redirect JSON.parse(shortner_json)["original_url"]
  end

  error 400..510 do 
    status 200
    @server_name = request.env['SERVER_NAME']
    @original_url = params[:original_url] unless params[:original_url].nil?
    haml :index 
  end
end

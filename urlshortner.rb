require 'rubygems'
require 'sinatra'
require 'redis'
require 'uri'
require 'json'

configure do
  require 'redis'
  uri = URI.parse(ENV["REDISTOGO_URL"])
  REDIS = Redis.new(:host => uri.host, :port => uri.port, :password => uri.password)
end

get '/' do 
  haml :index 
end

post '/' do
  uri = URI::parse(params[:original])
  raise "Invalid URL" unless uri.kind_of? URI::HTTP or uri.kind_of? URI::HTTPS
  
  shortner = {
    'original' => params[:original],
    'count' => 0,
    'short' => short_url
  }
  
  REDIS.set(short_url, shortner.to_json)
  
  @url = shortner
  haml :index
end

get '/:snipped' do 
  redis.multi do
    shortner = JSON.parse(REDIS.get(params[:snipped]))
    shortner.count = shortner.count + 1
    shortner.short = params[:snipped]
    REDIS.set(params[:snipped], shortner.to_json)
  end
  redirect shortner.original_url
end

error do 
  haml :index 
end

use_in_file_templates!

# DataMapper.setup(:default, ENV['DATABASE_URL'] || 'mysql://root:root@localhost/snip')
# class Url
#   include DataMapper::Resource
#   property :id, Serial
#   property :original, String, :length => 255
#   property :created_at, DateTime
#   def snipped() self.id.to_s(36) end
# end

__END__

@@ layout
!!! 1.1
%html
  %head
    %title Snip!
    %link{:rel => 'stylesheet', :href => 'http://www.w3.org/StyleSheets/Core/Modernist', :type => 'text/css'}
  = yield

@@ index
%h1.title Snip!
- unless @url.nil?
  %code= @url.original
  snipped to
  %a{:href => env['HTTP_REFERER'] + @url.short}
    = env['HTTP_REFERER'] + @url.short
#err.warning= env['sinatra.error']
%form{:method => 'post', :action => '/'}
  Snip this:
  %input{:type => 'text', :name => 'original', :size => '50'}
  %input{:type => 'submit', :value => 'snip!'}
%small copyright &copy;
%a{:href => 'http://blog.saush.com'}
  Chang Sau Sheong
%br
  %a{:href => 'http://github.com/sausheong/snip'}
    Full source code
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
    @urls_shortened = REDIS.get("short_url")
    haml :index 
  end

  post '/' do
    uri = URI::parse(params[:original_url])
    raise "Invalid URL" unless uri.kind_of? URI::HTTP or uri.kind_of? URI::HTTPS
  
    @urls_shortened = REDIS.incr("short_url")
    short_url = @urls_shortened.to_s(36)
      
    shortner = {
      :original_url => params[:original_url],
      :short_url => short_url
    }
  
    REDIS.set("short_url:#{short_url}", shortner.to_json)
  
    @url = shortner
    haml :index
  end

  get '/:short_url' do 
    shortner_json = REDIS.get("short_url:#{params[:short_url]}")
    
    raise "Url has not been shorted" if shortner_json.nil?
    
    redirect JSON.parse(shortner_json)["original_url"]
  end

  error do 
    haml :index 
  end

  def clippy(text, bgcolor='#FFFFFF')
    html = <<-EOF
      <object classid="clsid:d27cdb6e-ae6d-11cf-96b8-444553540000"
              width="110"
              height="14"
              id="clippy" >
      <param name="movie" value="/flash/clippy.swf"/>
      <param name="allowScriptAccess" value="always" />
      <param name="quality" value="high" />
      <param name="scale" value="noscale" />
      <param NAME="FlashVars" value="text=#{text}">
      <param name="bgcolor" value="#{bgcolor}">
      <embed src="/flash/clippy.swf"
             width="110"
             height="14"
             name="clippy"
             quality="high"
             allowScriptAccess="always"
             type="application/x-shockwave-flash"
             pluginspage="http://www.macromedia.com/go/getflashplayer"
             FlashVars="text=#{text}"
             bgcolor="#{bgcolor}"
      />
      </object>
    EOF
  end
  
  # enable :inline_templates
end

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
  %code= @url[:original_url]
  snipped to
  %a{:href => "#{ENV['HTTP_REFERER']}#{@url[:short_url]}"}
    = "#{ENV['HTTP_REFERER']}#{@url[:short_url]}"
#err.warning= env['sinatra.error']
%form{:method => 'post', :action => '/'}
  Snip this:
  %input{:type => 'text', :name => 'original_url', :size => '50'}
  %input{:type => 'submit', :value => 'snip!'}
%small copyright &copy;
%a{:href => 'http://blog.saush.com'}
  Chang Sau Sheong
%br
  %a{:href => 'http://github.com/sausheong/snip'}
    Full source code
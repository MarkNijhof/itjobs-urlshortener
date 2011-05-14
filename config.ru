require 'sinatra'
require './url_shortener.rb'
require './pretty_date.rb'

Time.send :include, PrettyDate

run UrlShortener
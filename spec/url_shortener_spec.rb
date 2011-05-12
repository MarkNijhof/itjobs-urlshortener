require File.dirname(__FILE__) + '/spec_helper'
require 'capybara/rspec'

describe "Url Shortener", :type => :request, :js => true, :redis => true do

  it "visiting the root should result in an empty form" do
    visit '/'

    find_field('original_url')['value'].should == ""
    find('#submit_button')['disabled'].should == "true"
    find('#short_url').text.should == "http://itjo.bs/..."
  end

  it "will enable the submit button after filling out an url" do
    visit '/'
    fill_in('original_url', :with => 'http://cre8ivethought.com/')

    find('#submit_button')['disabled'].should == "false"
  end

  it "will disable the submit button after removing an url" do
    visit '/'
    fill_in('original_url', :with => 'http://cre8ivethought.com/')
    fill_in('original_url', :with => '')

    find('#submit_button')['disabled'].should == "true"
  end

  it "providing a long url and clicking the button will result in a short url" do
    visit '/'
    fill_in('original_url', :with => 'http://cre8ivethought.com/')
    click_button('Shorten')
    
    find('#submit_button')['disabled'].should == "true"
    page.should have_content("http://itjo.bs/1")
  end

  it "providing a short url will redirect to the long url" do
    visit '/'
    fill_in('original_url', :with => 'http://localhost/')
    click_button('Shorten')
    visit '/1'
    
    current_url.should == "http://localhost/"
  end

  it "providing a short url with a + sign appended it will redirect to the inspect url" do
    visit '/'
    fill_in('original_url', :with => 'http://localhost/')
    click_button('Shorten')
    visit '/1+'
    
    current_path.should == "/1/inspect"
  end

  it "going to the inspect page will show the original url and stats" do
    visit '/'
    fill_in('original_url', :with => 'http://localhost/')
    click_button('Shorten')
    visit '/1/inspect'
    
    find_field('original_url')['value'].should == "http://localhost/"
    find('#submit_button')['disabled'].should == "true"
    find('#short_url').text.should == "http://itjo.bs/1"    
    find('#counter').text.should == "( expanded 0 times )"    
  end

  it "the stats are being updated correctly" do
    visit '/'
    fill_in('original_url', :with => 'http://localhost/')
    click_button('Shorten')
    visit '/1'
    visit '/1'
    visit '/1/inspect'
    
    find('#counter').text.should == "( expanded 2 times )"
    
  end

end

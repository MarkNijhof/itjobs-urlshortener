# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require 'rake'
require '../secret_stuff/itjobs-urlshortner/rakefile' if FileTest.exists?('../secret_stuff/itjobs-urlshortner/rakefile.rb')

task :run => [:set_development_environment] do
  # sh "thin start"
  sh "shotgun config.ru -s thin -E production" 
  # sh "thin start -R config.ru " #-a local.cre8ivethought.com"
  # sh "rackup -o local.cre8ivethought.com -p 3000"
end

task :test => [:set_test_environment] do
  sh "rspec spec"
end
 
# task :neo_stop do
#   sh "~/neo4j-server-dev/bin/neo4j stop"
#   sh "~/neo4j-server/bin/neo4j stop"
# end
# 
# task :neo_start do
#   sh "~/neo4j-server-dev/bin/neo4j start"
#   sh "~/neo4j-server/bin/neo4j start"
# end
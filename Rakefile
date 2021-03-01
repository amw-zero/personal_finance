# frozen_string_literal: true

def in_utc_timezone(cmd)
  "TZ=UTC #{cmd}"
end

task :test, [:file] do |_, args|
  puts "Running file: #{args[:file]} --"
  system(in_utc_timezone("bundle exec rspec #{args[:file]}"))
end

task :serve do
  system(in_utc_timezone('ruby web_server/server.rb'))
end

#!/usr/bin/env jruby
#
# Description: Fetches the content from the list of URLs provided
# on the command line and stores that content and its response code
# in a MongoDB database.
#
# Usage: jruby -rubygems -Ilib bin/fetch.rb urls.txt
#
# Dependencies:
#
# * jruby-http-reactor
# * beanstalk-client
# * threadify
# * mongo_mapper

require 'uri'
require 'http_reactor'
require 'threadify'
require 'beanstalk-client'
require 'mongomapper'

$stdout.sync = true

processes = 16

MongoMapper.connection = Mongo::Connection.new(nil, nil, :auto_reconnect => true)
MongoMapper.database = 'publishing_platform'

require 'feed_processor'

def requests
  @requests ||= begin
    puts "Generating requests"
    requests = []
    open(ARGV.pop) do |f|
      f.each do |line|
        requests << HttpReactor::Request.new(URI.parse(line)) if line =~ /^http:/
      end
    end
    puts "Generated #{requests.length} requests"
    requests
  end
end

# Processing
main_queue = Beanstalk::Pool.new(['localhost:11300'])
number_of_requests = requests.length
main_queue.put("START #{number_of_requests}")
slice_size = number_of_requests / processes
puts "Each slice has #{slice_size} urls, running #{processes} processes"
requests.threadify(:each_slice, slice_size) do |slice|
  queue = Beanstalk::Pool.new(['localhost:11300'])
  HttpReactor::Client.new(slice) do |response, context|
    begin
      request = context.get_attribute('http_target_request')
      puts "#{response.code}:#{request.uri}"
      
      Response.create({
        :url => request.uri, 
        :data => decode_content(response), 
        :status => response.code
      })
    
      if response.code == 200
        queue.put(request.uri.to_s)
      end
    rescue Exception => e
      puts "Exception in handler: #{e.message}"
    end
  end
end
main_queue.put("END #{number_of_requests}")
puts "Processed #{number_of_requests} feeds"
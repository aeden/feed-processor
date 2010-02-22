require 'mongo_mapper'
require 'uri'
require 'http_reactor'
require 'threadify'
require 'beanstalk-client'

module FeedProcessor
  class Fetcher
    attr_reader :options
    
    def initialize(options={})
      @options = options
      @request_generator = options[:request_generator] || FeedProcessor::FileBasedRequestGenerator.new
      setup_mongo(options[:mongo])
    end
    
    def requests
      @request_generator.requests
    end

    def execute
      number_of_threads = options[:threads] || 16
      main_queue = Beanstalk::Pool.new(['localhost:11300'])
      
      number_of_requests = requests.length
      main_queue.put("START #{number_of_requests}")
      slice_size = number_of_requests / number_of_threads
      slice_size = 1 if slice_size < 1
      puts "Each slice has #{slice_size} urls (#{number_of_requests} requests / #{number_of_threads} threads)"
    
      requests.threadify(:each_slice, slice_size) do |slice|
        queue = Beanstalk::Pool.new(['localhost:11300'])
        HttpReactor::Client.new(slice) do |response, context|
          begin
            request = context.get_attribute('http_target_request')
            puts "#{response.code}:#{request.uri}"
    
            Response.create({
              :url => request.uri, 
              :data => FeedProcessor::Util.decode_content(response), 
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
      puts "Fetched #{number_of_requests} feeds"
      
    end
  
    protected
    def setup_mongo(options={})
      options ||= {}
      options[:database] ||= 'feed_processor'
      MongoMapper.connection = Mongo::Connection.new(nil, nil)
      MongoMapper.database = options[:database]
    end
  end
end
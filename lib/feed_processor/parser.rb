require 'mongo_mapper'
require 'beanstalk-client'
require 'feedzirra'

module FeedProcessor
  class Parser
    attr_reader :options
    
    def initialize(options={})
      @options = options
      @feed_handler = options[:feed_handler] || FeedProcessor::MongoFeedHandler.new
      setup_mongo(options[:mongo])
    end
    def execute
      queue = Beanstalk::Pool.new(['localhost:11300'])
      puts "Now accepting feeds to parse..."
      begin
        loop do
          job = queue.reserve
          if job.body =~ /^START (.+)$/
            puts "starting #{$1} feeds"
          elsif job.body =~ /^END (.+)$/
            puts "finished #{$1} feeds"
          else
            url = job.body
            puts "parsing #{url}"
            responses = Response.all(:conditions => {'url' => url})
            responses.each do |response|
              begin
                feed = Feedzirra::Feed.parse(response.data)
                @feed_handler.process(url, feed)
              rescue => e
                puts "error parsing feed #{url}: #{e.message}"
              end
              response.destroy
            end
          end
          job.delete
        end
      rescue Interrupt
        puts "Exiting parser"
      end
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
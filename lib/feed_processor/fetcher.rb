module FeedProcessor
  class Fetcher
    attr_reader :options
    
    def initialize(options={})
      @options = options
    end
    
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

    def execute
      number_of_threads = options[:threads] || 16
      main_queue = Beanstalk::Pool.new(['localhost:11300'])
      number_of_requests = requests.length
      main_queue.put("START #{number_of_requests}")
      slice_size = number_of_requests / number_of_threads
      puts "Each slice has #{slice_size} urls (#{number_of_threads} threads)"
      
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
      puts "Processed #{number_of_requests} feeds"
    end
  end
end
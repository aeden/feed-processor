module FeedProcessor
  class FileBasedRequestGenerator
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
  end
end
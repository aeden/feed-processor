module FeedProcessor
  class Parser
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
            responses = Response.find(:all, :conditions => {'url' => url})
            responses.each do |response|
              begin
                feed = Feedzirra::Feed.parse(response.data)
                f = Feed.create({:url => url, :status => 'to-process'})
                entries = feed.entries
                puts "found #{entries.length} entries in #{url}"
                entries.each do |entry|
                  begin
                    f.contents.create({
                      :title => entry.title,
                      :url => entry.url,
                      :author => entry.author,
                      :summary => entry.summary,
                      :content => entry.content,
                      :published => entry.published,
                      :categories => entry.categories,
                    })
                  rescue => e
                    puts "error creating entry #{entry.url}: #{e.message}"
                  end
                end
              rescue => e
                puts "error parsing feed #{url}: #{e.message}"
              end
            end
          end
          job.delete
        end
      rescue Interrupt
        puts "Exiting parser"
      end
    end
  end
end
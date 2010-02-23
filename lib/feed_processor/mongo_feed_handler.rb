module FeedProcessor
  class MongoFeedHandler
    def process(url, feed)
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
    end
  end
end
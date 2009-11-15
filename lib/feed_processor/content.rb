require 'mongomapper'

class Content
  include MongoMapper::Document
  
  key :title, String
  key :url, String
  key :author, String
  key :summary, String
  key :content, String
  key :published, Date
  key :categories, Array
  key :feed_id, String
  
  belongs_to :feed
  
  validates_uniqueness_of :url
  
end
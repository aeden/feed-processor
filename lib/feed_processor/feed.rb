require 'mongo_mapper'

class Feed
  include MongoMapper::Document
  
  key :title, String
  key :url, String
  key :status, String
  
  many :contents
  
  validates_uniqueness_of :url
end
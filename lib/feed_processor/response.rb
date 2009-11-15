require 'mongomapper'

class Response
  include MongoMapper::Document
  
  key :url, String
  key :data, String
  key :status, String
  
  validates_uniqueness_of :url
end
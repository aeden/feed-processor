# shamelessly stolen from feedzirra
def decode_content(res)
  case res['content-encoding']
  when 'gzip'
    begin
      gz =  Zlib::GzipReader.new(StringIO.new(res.body))
      xml = gz.read
      gz.close
    rescue Zlib::GzipFile::Error 
      # Maybe this is not gzipped?
      xml = res.body
    end
  when 'deflate'
    xml = Zlib::Inflate.inflate(res.body)
  else
    xml = res.body
  end

  xml
end
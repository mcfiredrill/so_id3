require 'rupeepeethree'
require 'open-uri'
require 'aws'

module SoId3
  class Tags
    VALID_TAGS = [
      'artist',
      'title',
      'album',
      'year',
      'track'
    ]
    attr_accessor :tagger
    attr_accessor :cache
    def initialize mp3, cache, storage, s3_credentials = {}
      if storage == :s3
        @mp3 = open(mp3).path
        @s3 = AWS::S3.new(access_key_id: s3_credentials[:access_key_id],
                          secret_access_key: s3_credentials[:secret_access_key])
        @bucket = @s3.buckets.create(s3_credentials[:bucket])
      else
        @mp3 = mp3
      end
      @tagger = Rupeepeethree::Tagger
      @cache = cache
      @storage = storage.to_sym
    end

    # accepts a hash of tag values
    #
    # useful for updating tags all at once in a background process
    def update_tags(tags)

    end

    VALID_TAGS.each do |tag_name|
      define_method tag_name do
        # if cached? grab from database else grab from tags and store in db
        if !@cache.send(tag_name).nil?
          @cache.send(tag_name)
        else
          tag = @tagger.tags(@mp3).fetch(tag_name.to_sym)
          write_tag_to_cache tag_name, tag
          tag
        end
      end
      define_method "#{tag_name}=" do |text|
        # write tag with tagger and store in db
        tags = {}
        tags[tag_name.to_sym] = text
        if @storage == :s3
          # grab file from s3
          # store in /tmp/
          # tag
          # re-upload to s3
          @tagger.tag(@mp3, tags)
          key = File.basename(@mp3)
          @bucket.objects[key].write(file: @mp3, acl: :public_read)
        else
          @tagger.tag(@mp3, tags)
        end
        write_tag_to_cache tag_name, text
      end
    end

    private
    def write_tag_to_cache tag_name, text
      @cache.send("#{tag_name}=".to_sym, text)
    end
  end
end

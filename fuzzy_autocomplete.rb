require 'rubygems'
require 'redis'
require 'yajl'
require 'logger'

module FuzzyComplete
  
  class CharacterRun < Struct.new(:string, :inside) #:nodoc:
    def to_s
      if inside
        "(#{string})"
      else
        string
      end
    end
  end
  
  class CodecError < StandardError
    attr_reader :object, :error
    def initialize(object, error)
      @object = object
      @error  = error
    end
  end
  
  module Codec
    class YajlCodec
    
      def encode(object)
        self.class.encoder.encode(object)
      end
    
      def decode(arr)
        json = arr.inject(""){|str, json_obj| str << json_obj; str }
        objs = []
        self.class.parser.parse(json) do |parsed|
          objs << parsed
        end
        objs
      rescue StandardError => e
        @parser = nil
        # TODO: Handle parse errors. Encoder seems to be serializing or
        # deserializing utf8 chars wrong or something
        # raise CodecError.new(json, e)
        raise
      end
    
      def self.encoder
        @encoder ||= Yajl::Encoder.new
      end
      def self.parser
        @parser ||= Yajl::Parser.new(:symbolize_keys => true)
      end
    
    end
  
    class ProtobufCodec
    
      def initialize
        require 'fuzzycomplete.pb'
      end
    
      def encode(object)
        self.class.object_to_protobuf(object).serialize_to_string
      end
    
      def decode(arr)
        arr.map do |e|
          Fuzzycomplete::User.parse(e)
        end
      end
    
      def self.object_to_protobuf(object)
        Fuzzycomplete::User.new(object)
      end
    
    end
  end
  
end


module FuzzyComplete

  CACHE_PREFIX = 'fuzzycomplete'

  class Find
  
    def initialize(data, namespace, redis = Redis.new, codec = YajlCodec.new)
      @data = data
      @namespace = namespace
      @redis = redis
      @codec = codec
    end
  
    def pattern_key(bucket, pattern)
      "#{CACHE_PREFIX}:#{@namespace}:#{bucket}:#{pattern}"
    end
  
    def find(bucket, pattern, max=nil)
      logger.info{ "Find bucket[#{bucket}] pattern[#{pattern}]" }
      results = []
      search(pattern) do |match|
        results << match
        break if max && results.length >= max
      end
      return results.sort_by{|r| -r[:score] }
    end

    def find_with_redis(bucket, pattern, max=nil)
      cached = self.decode(@redis.zrevrange(pattern_key(bucket, pattern), 0, -1))
      if cached.size > 0
        logger.debug{ "Got cached results" }
        cached
      else
        logger.debug{ "Finding and adding to cache" }
        results = find_without_redis(bucket, pattern, max)
        results.each do |result|
          @redis.zadd(pattern_key(bucket, pattern), result[:score], self.encode(result))
        end
        results
      end
    end
    alias find_without_redis find
    alias find find_with_redis
  
    def search(query, &block)
      pattern = self.class.make_pattern(query)
    
      name_matches = {}
      @data.each do |entry|
        match_entry(entry, pattern, &block)
      end
    
    end

    def match_entry(entry, pattern, &block)
      name,permalink = entry.split('|')
    
      name_match = name.match(pattern)
      permalink_match = permalink.match(pattern)
    
      if name_match || permalink_match
        name_match_result = build_match_result(name_match)
        permalink_match_result = build_match_result(permalink_match)
    
        result = { :name => name,
                   :permalink => permalink,
                   :highlighted_name => name_match_result[:result],
                   :highlighted_permalink => permalink_match_result[:result],
                   :score => [1.5 * name_match_result[:score], permalink_match_result[:score]].max }
        yield result
      end
    end

    def build_match_result(match)
      return {:score => 0.0} unless match
      runs = []
      misses = []
      inside_chars = total_chars = 0
      match.captures.each_with_index do |capture, index|
        if capture.length > 0
          # odd-numbered captures are matches inside the pattern.
          # even-numbered captures are matches between the pattern's elements.
          inside = index % 2 != 0

          total_chars += capture.length
          inside_chars += capture.length if inside

          if runs.last && runs.last.inside == inside
            runs.last.string << capture
          else
            runs << CharacterRun.new(capture, inside)
          end
        end
      end

      # Determine the score of this match.
      # 1. fewer "inside runs" (runs corresponding to the original pattern)
      #    is better.
      # 2. better coverage of the actual path name is better
      inside_segments = 1.0
      inside_runs = runs.select { |r| r.inside }
      run_ratio = inside_runs.length.zero? ? 1.0 : inside_segments.to_f / inside_runs.length.to_f

      char_ratio = total_chars.zero? ? 1.0 : inside_chars.to_f / total_chars.to_f

      score = run_ratio * char_ratio

      return { :score => score, :result => runs.join }
    end
  
    def self.make_pattern(pattern)
      pattern = pattern.split(//)
      pattern << "" if pattern.empty?

      pattern = pattern.inject("") do |regex, character|
        regex << "(.*?)" if regex.length > 0
        regex << "(" << Regexp.escape(character) << ")"
      end
    
      pattern = "^(.*?)" + pattern + "(.*)$"
      Regexp.new(pattern, Regexp::IGNORECASE)
    end
  
    def invalidate!(bucket, pattern)
      self.class.invalidation_patterns(pattern) do |partial_pattern|
        @redis.del(pattern_key(bucket, partial_pattern))
      end
    end
  
    def self.invalidation_patterns(str)
      chars = str.split(//)
      (1..chars.size).each do |combo_size|
        chars.combination(combo_size){|c| yield c.join }
      end
    end
  
    def encode(obj)
      logger.debug{ "Encoding: #{obj.inspect}" }
      @codec.encode(obj)
    end

    def decode(arr)
      logger.debug{ "Decoding #{arr.join}" }
      @codec.decode(arr)
    end
  
    def self.logger
      @logger ||= Logger.new($stdout)
    end
  
    attr_reader :logger
    def logger; self.class.logger; end
    
  end
end

# c = FuzzyComplete.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, :protobuf)
# c.logger.level = Logger::WARN
# c.find('user', ARGV[0]).each{|r| puts [r[:highlighted_name], r[:highlighted_permalink], r[:score]].inspect }

require 'benchmark'

people = File.readlines('names.txt').map(&:chomp).map{|line| line.split('|')}

c_yajl   = FuzzyComplete::Find.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::YajlCodec.new)
c_protob = FuzzyComplete::Find.new(File.readlines('names.txt').map(&:chomp), 'foobar', Redis.new, FuzzyComplete::Codec::ProtobufCodec.new)

c_yajl.logger.level = Logger::WARN
c_protob.logger.level = Logger::WARN

puts "Generating query terms"
query_terms = (0..500).to_a.map do |i|
  name, permalink = people[rand(people.size)]
  terms = [name, permalink].compact
  term = terms[rand(terms.size)]
  p0 = rand(term.size)
  len = rand(term.size - p0)
  term[p0, len]
end


Benchmark.bm do |x|
  x.report('yajl     ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_yajl.find('user', term)
    end
  end
  x.report('protobuf ') do
    system 'ruby clear.rb >/dev/null'
    query_terms.each do |term|
      c_protob.find('user', term)
    end
  end
end

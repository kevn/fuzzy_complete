require 'redis'
require 'logger'

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


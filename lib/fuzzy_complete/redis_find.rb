
module FuzzyComplete
  class RedisFind < Find

    def find(bucket, pattern, max=nil)
      cached = self.decode(@redis.zrevrange(pattern_key(bucket, pattern), 0, -1))
      if cached.size > 0
        logger.debug{ "Got cached results" }
        cached
      else
        logger.debug{ "Finding and adding to cache" }
        results = super
        results.each do |result|
          @redis.zadd(pattern_key(bucket, pattern), result[:score], self.encode(result))
        end
        results
      end
    end

  end
end

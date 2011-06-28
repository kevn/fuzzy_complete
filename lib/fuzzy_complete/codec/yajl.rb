require 'yajl'

module FuzzyComplete
  module Codec

    class Yajl

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
        @encoder ||= ::Yajl::Encoder.new
      end

      def self.parser
        @parser ||= ::Yajl::Parser.new(:symbolize_keys => true)
      end

    end

  end
end


module FuzzyComplete
  module Codec

    class Protobuf

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

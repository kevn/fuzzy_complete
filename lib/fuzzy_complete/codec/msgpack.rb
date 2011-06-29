require 'msgpack'

module FuzzyComplete
  module Codec

    class Msgpack

      def encode(object)
        ::MessagePack.pack(object)
      end

      def decode(arr)
        arr.inject([]) do |a, obj|
          a << ::MessagePack.unpack(obj)
          a
        end
      # rescue StandardError => e
      #   raise CodecError.new(obj, e)
      end

    end

  end
end

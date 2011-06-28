
module FuzzyComplete
  module Codec

    class CodecError < StandardError
      attr_reader :object, :error
      def initialize(object, error)
        @object = object
        @error  = error
      end
    end

  end
end

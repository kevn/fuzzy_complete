#!/usr/bin/env ruby
# Generated by the protocol buffer compiler. DO NOT EDIT!

require 'protocol_buffers'

# Reload support
Object.__send__(:remove_const, :Fuzzycomplete) if defined?(Fuzzycomplete)

module Fuzzycomplete
  # forward declarations
  class User < ::ProtocolBuffers::Message; end

  class User < ::ProtocolBuffers::Message
    optional :string, :name, 1
    optional :string, :permalink, 2
    optional :string, :highlighted_name, 3
    optional :string, :highlighted_permalink, 4
    optional :float, :score, 5

    gen_methods! # new fields ignored after this point
  end

end
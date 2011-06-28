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
  
end

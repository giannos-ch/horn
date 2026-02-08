require "../../solution"
require "../../values/*"
require "./logic"

module Horn
  module Strategies
    class HT < Strategy
      class Interpretation < Solution
        getter map : Hash(Expressions::Const, Value)

        def initialize(@map)
        end

        def [](const : Expressions::Const)
          @map[const]
        end

        def print(io : IO)
          to_s(io)
        end

        def to_s(io)
          io << "{"
          @map.each_with_index do |(const, value), i|
            io << ", " if i > 0
            io << "#{const}: #{value}"
          end
          io << "}"
        end

        def ht_le(other : Interpretation)
          @map.each do |const, val1|
            val2 = other.map[const]
            return false unless Logic.ht_le(val1, val2)
          end
          true
        end
      end
    end
  end
end

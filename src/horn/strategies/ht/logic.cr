require "../../values/*"
require "../../expressions/const"

module Horn
  module Strategies
    class HT < Strategy
      module Logic
        include Values

        def self.truth_le(v1, v2)
          return true if v1 == v2
          case v1
          when False
            true
          when TStar
            v2.is_a?(True)
          when Map
            return false unless v2.is_a?(Map)
            v1.values.each do |k, val1|
              val2 = v2.values[k]
              return false unless truth_le(val1, val2)
            end
            true
          else
            false
          end
        end

        def self.ht_le(v1, v2)
          return true if v1 == v2
          case v1
          when TStar
            v2.is_a?(True)
          when Map
            return false unless v2.is_a?(Map)
            v1.values.each do |k, val1|
              val2 = v2.values[k]
              return false unless ht_le(val1, val2)
            end
            true
          else
            false
          end
        end

        def self.is_total?(interp : Interpretation) : Bool
          interp.map.values.all? { |v| is_total?(v) }
        end

        def self.is_total?(v) : Bool
          case v
          when TStar
            false
          when Map
            v.values.each do |input, output|
              if is_total?(input)
                return false unless is_total?(output)
              end
            end
            true
          else
            true
          end
        end
      end
    end
  end
end

require "./type"

module Horn
  module Types
    class I < Type
      def to_s(io)
        io << "ι"
      end

      def inspect(io)
        io << "ι"
      end

      def hash(hasher)
        self.class.hash(hasher)
      end

      def ==(other)
        other.is_a?(I)
      end
    end
  end
end

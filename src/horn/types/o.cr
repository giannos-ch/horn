require "./type"

module Horn
  module Types
    class O < Type
      def predicate?
        true
      end

      def to_s(io)
        io << "ο"
      end

      def inspect(io)
        io << "ο"
      end

      def hash(hasher)
        self.class.hash(hasher)
      end

      def ==(other)
        other.is_a?(O)
      end
    end
  end
end

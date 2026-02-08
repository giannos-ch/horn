require "./value"

module Horn
  module Values
    class TStar < Value
      def to_s(io)
        io << "T*"
      end

      def inspect(io)
        io << "T*"
      end

      def ==(other)
        other.is_a?(TStar)
      end

      def hash(hasher)
        self.class.hash(hasher)
      end
    end
  end
end

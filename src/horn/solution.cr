require "set"

module Horn
  abstract class Solution
    abstract def print(io : IO)

    def to_s(io)
      print(io)
    end
  end

  class QueryResult < Solution
    getter query : Expr?
    getter result : Value

    def initialize(@query, @result)
    end

    def print(io : IO)
      if q = @query
        io << q << " => "
      end
      @result.print(io)
    end
  end

  class DNFResult < Solution
    getter query : Expr?
    getter conjuncts : Set(Expr)

    def initialize(@query, @conjuncts)
    end

    def print(io : IO)
      if q = @query
        io << q << " => "
      end
      io << conjuncts.join(", ")
    end
  end
end

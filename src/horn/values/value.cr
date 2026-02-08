module Horn
  abstract class Value
    def true?
      false
    end

    def false?
      false
    end

    def undef?
      false
    end

    def print(io : IO)
      to_s(io)
    end

    def |(other)
      raise "Not implemented"
    end

    def &(other)
      raise "Not implemented"
    end

    def ~
      raise "Not implemented"
    end

    def to_json(builder : JSON::Builder)
      self.to_s.to_json(builder)
    end
  end
end

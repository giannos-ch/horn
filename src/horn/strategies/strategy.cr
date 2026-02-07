module Horn
  abstract class Strategy
    def self.with_name(name : String)
      {{Strategy.subclasses}}.find { |s| s.name == name }
    end

    def visualize
      raise "Not implemented"
    end

    def solve(&)
      raise "Not implemented"
    end
  end
end

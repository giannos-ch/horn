module Horn
  abstract class Strategy
    def self.with_name(name : String)
      {{Strategy.subclasses}}.find { |s| s.name == name }
    end

    def visualize : String
      ""
    end

    def solve(&block : Solution -> Nil)
      raise "Not implemented"
    end
  end
end

require "json"
require "./expressions/expr"
require "./expressions/const"

module Horn
  class Program
    include JSON::Serializable
    getter rules = Hash(Expressions::Const, Expr).new
    getter queries = Array(Expr).new

    def initialize
    end
  end
end

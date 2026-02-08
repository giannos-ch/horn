require "../caching"
require "../const_collection"
require "../expressions/*"
require "../program"
require "../state"
require "../types/*"
require "../values/*"
require "../var_helper"
require "../visualizer"
require "./strategy"

module Horn
  class TopDown < Strategy
    include VarHelper
    include Expressions

    @visualizer = Visualizer.new

    def initialize(@program : Program, @const_collection : ConstCollection)
      @cache = Caching(Expr, Value).new(->cache_valid?(Expr))
    end

    def solve(&)
      @program.queries.each do |query|
        yield QueryResult.new(query, eval(query))
      end
    end

    def eval(expr : Expr) : Value
      eval(expr, nil)
    end

    def eval(expr : Expr, parent_id : String?) : Value
      expr = expr.as(Expr)
      visualizer_node = @visualizer.new_node(expr, parent_id)

      visualizer_node.value = Values::FalseByDefault.new(expr)
      if cached = @cache[expr]
        visualizer_node.value = cached
        return cached
      end
      @cache[expr] = Values::FalseByDefault.new(expr)

      value =
        case expr
        when True
          Values::True.new
        when False
          Values::False.new
        when Const, Appl
          r = reduct(expr)
          raise "Cannot reduce #{expr}" unless r[1]
          eval(r[0], visualizer_node.id)
        when Lambda
          @const_collection.select do |const, type|
            type == (expr.param_type || Types::I.new)
          end.keys.each_with_object(Values::Map.new) do |const, set|
            set[const] = eval(Appl.new(expr, const), visualizer_node.id)
          end
        when And
          if (val = eval(expr.left, visualizer_node.id)).is_a?(Values::False)
            val
          else
            val & eval(expr.right, visualizer_node.id)
          end
        when Or
          if (val = eval(expr.left, visualizer_node.id)).is_a?(Values::True)
            val
          else
            val | eval(expr.right, visualizer_node.id)
          end
        when Not
          ~eval(expr.expr, visualizer_node.id)
        when Eq
          if !@const_collection.has_key?(expr.left) || @const_collection[expr.left] != @const_collection[expr.right]?
            raise "Cannot compare #{expr.left} to #{expr.right}"
          end
          (expr.left == expr.right) ? Values::True.new : Values::False.new
        when Exists
          @const_collection.select do |const, type|
            type == expr.var_type
          end.keys.map do |const|
            if (val = eval(Appl.new(Lambda.new(expr.var, expr.var_type, expr.expr), const), visualizer_node.id)).true?
              break [val]
            end
            val.as(Value)
          end.reduce do |acc, val|
            acc | val
          end
        else
          raise "Unknown expression: #{expr}"
        end

      value.due_to.delete(expr) if value.is_a?(Values::FalseByDefault)
      visualizer_node.value = value
      @cache[expr] = value

      value
    end

    def reduct(expr : Expr) : {Expr, Bool}
      case expr
      when True, False, Var, Eq, Not
        {expr, false}
      when Lambda
        r = reduct(expr.body)
        {Lambda.new(expr.param, expr.param_type, r[0]), r[1]}
      when And
        r = reduct(expr.left)
        if r[1]
          {And.new(r[0], expr.right), true}
        else
          r = reduct(expr.right)
          {And.new(expr.left, r[0]), r[1]}
        end
      when Or
        r = reduct(expr.left)
        if r[1]
          {Or.new(r[0], expr.right), true}
        else
          r = reduct(expr.right)
          {Or.new(expr.left, r[0]), r[1]}
        end
      when Exists
        r = reduct(expr.expr)
        {Exists.new(expr.var, expr.var_type, r[0]), r[1]}
      when Appl
        func, arg = expr.func, expr.arg
        case func
        when False
          {False.new, true}
        when Lambda
          {assign_vars(func.body, {func.param => arg}), true}
        when And
          {And.new(Appl.new(func.left, arg), Appl.new(func.right, arg)), true}
        when Or
          {Or.new(Appl.new(func.left, arg), Appl.new(func.right, arg)), true}
        else
          r = reduct(func)
          if r[1]
            {Appl.new(r[0], arg), true}
          else
            r = reduct(arg)
            {Appl.new(func, r[0]), r[1]}
          end
        end
      when Const
        if !@const_collection[expr].predicate?
          {expr, false}
        elsif @program.rules.has_key?(expr)
          {@program.rules[expr], true}
        else
          {False.new, true}
        end
      else
        raise "Unknown expression: #{expr}"
      end
    end

    def visualize
      @visualizer.to_json
    end

    private def cache_valid?(expr : Expr)
      case expr
      when Appl
        cache_valid?(expr.func) && cache_valid?(expr.arg)
      when Const
        @const_collection.has_key?(expr)
      else
        false
      end
    end

    protected def self.name
      "top_down"
    end
  end
end

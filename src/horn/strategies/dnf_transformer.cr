require "../const_collection"
require "../expressions/*"
require "../program"
require "../types/*"
require "../values/*"
require "../var_helper"
require "../visualizer"
require "./strategy"
require "./top_down"

module Horn
  class DNFTransformer < Strategy
    include VarHelper
    include Expressions

    @visualizer = Visualizer.new

    def initialize(@program : Program, @const_collection : ConstCollection)
      @cache = Caching(Set(Expr), Bool).new(->cache_valid?(Set(Expr)))
      @top_down = TopDown.new(@program, @const_collection)
    end

    def run(expr : Expr, &)
      @cache.reset
      disjucts = Array({Expr, String?}).new
      disjucts << {expr, nil}
      while (expr_and_parent_id = disjucts.last?)
        disjucts.pop
        expr, parent_id = expr_and_parent_id
        conjuncts = conjuncts(expr).to_set
        next unless consistent?(conjuncts)
        next if @cache[conjuncts]
        @cache[conjuncts] = true
        loop do
          visualizer_node = @visualizer.new_node(expr, parent_id)
          parent_id = visualizer_node.id
          if expr.is_a?(Or)
            disjucts << {expr.right, parent_id}
            expr = expr.left
          end
          expr, changed = top_down(expr)
          next if changed
          expr, changed = logic_transform(expr)
          next if changed
          expr, changed = beta_reduct(expr)
          next if changed
          expr, changed = unfold_quantifiers(expr)
          next if changed
          expr, changed = unfold_const(expr)
          next if changed

          break if expr.is_a?(False)
          conjuncts = conjuncts(expr)
          break unless consistent?(conjuncts)
          yield conjuncts.to_set
          break
        end
      end
    end

    def eval(expr : Expr) : Expr
      disjuncts = Array(Expr).new
      run(expr) do |disjunct|
        disjuncts << And.from_list(disjunct.to_a)
      end
      disjuncts.empty? ? False.new : Or.from_list(disjuncts)
    end

    def beta_reduct(expr : Expr) : {Expr, Bool}
      case expr
      when Appl
        func, arg = expr.func, expr.arg
        case func
        when Lambda
          {assign_vars(func.body, {func.param => arg}), true}
        else
          r = beta_reduct(func)
          if r[1]
            {Appl.new(r[0], arg), true}
          else
            r = beta_reduct(arg)
            {Appl.new(func, r[0]), r[1]}
          end
        end
      when Exists
        r = beta_reduct(expr.expr)
        {Exists.new(expr.var, expr.var_type, r[0]), r[1]}
      when Forall
        r = beta_reduct(expr.expr)
        {Forall.new(expr.var, expr.var_type, r[0]), r[1]}
      when Lambda
        r = beta_reduct(expr.body)
        {Lambda.new(expr.param, expr.param_type, r[0]), r[1]}
      when Not
        r = beta_reduct(expr.expr)
        {Not.new(r[0]), r[1]}
      when And
        r = beta_reduct(expr.left)
        if r[1]
          {And.new(r[0], expr.right), true}
        else
          r = beta_reduct(expr.right)
          {And.new(expr.left, r[0]), r[1]}
        end
      when Or
        r = beta_reduct(expr.left)
        if r[1]
          {Or.new(r[0], expr.right), true}
        else
          r = beta_reduct(expr.right)
          {Or.new(expr.left, r[0]), r[1]}
        end
      else
        {expr, false}
      end
    end

    def logic_transform(expr : Expr) : {Expr, Bool}
      case expr
      when Appl
        func, arg = expr.func, expr.arg
        r = logic_transform(func)
        return {Appl.new(r[0], arg), true} if r[1]
        r = logic_transform(arg)
        return {Appl.new(func, r[0]), true} if r[1]
        case func
        when And
          {And.new(Appl.new(func.left, arg), Appl.new(func.right, arg)), true}
        when Or
          {Or.new(Appl.new(func.left, arg), Appl.new(func.right, arg)), true}
        else
          {expr, false}
        end
      when Exists
        r = logic_transform(expr.expr)
        {Exists.new(expr.var, expr.var_type, r[0]), r[1]}
      when Forall
        r = logic_transform(expr.expr)
        {Forall.new(expr.var, expr.var_type, r[0]), r[1]}
      when Lambda
        r = logic_transform(expr.body)
        {Lambda.new(expr.param, expr.param_type, r[0]), r[1]}
      when And
        if expr.left.is_a?(False) || expr.right.is_a?(False)
          {False.new, true}
        elsif expr.left.is_a?(True)
          {expr.right, true}
        elsif expr.right.is_a?(True)
          {expr.left, true}
        elsif (left_and_expr = expr.left).is_a?(Or)
          {Or.new(And.new(left_and_expr.left, expr.right), And.new(left_and_expr.right, expr.right)), true}
        elsif (right_and_expr = expr.right).is_a?(Or)
          {Or.new(And.new(expr.left, right_and_expr.left), And.new(expr.left, right_and_expr.right)), true}
        else
          r = logic_transform(expr.left)
          if r[1]
            {And.new(r[0], expr.right), true}
          else
            r = logic_transform(expr.right)
            {And.new(expr.left, r[0]), r[1]}
          end
        end
      when Or
        if expr.left.is_a?(False)
          {expr.right, true}
        elsif expr.right.is_a?(False)
          {expr.left, true}
        else
          r = logic_transform(expr.left)
          if r[1]
            {Or.new(r[0], expr.right), true}
          else
            r = logic_transform(expr.right)
            {Or.new(expr.left, r[0]), r[1]}
          end
        end
      when Not
        not_expr = expr.expr
        case not_expr
        when True
          {False.new, true}
        when False
          {True.new, true}
        when Not
          {not_expr.expr, true}
        when And
          {Or.new(Not.new(not_expr.left), Not.new(not_expr.right)), true}
        when Or
          {And.new(Not.new(not_expr.left), Not.new(not_expr.right)), true}
        when Exists
          {Forall.new(not_expr.var, not_expr.var_type, Not.new(not_expr.expr)), true}
        when Forall
          {Exists.new(not_expr.var, not_expr.var_type, Not.new(not_expr.expr)), true}
        else
          r = logic_transform(expr.expr)
          {Not.new(r[0]), r[1]}
        end
      when Eq
        left, right = expr.left, expr.right
        if left.is_a?(Const) && right.is_a?(Const)
          {(expr.left == expr.right) ? True.new : False.new, true}
        else
          {expr, false}
        end
      else
        {expr, false}
      end
    end

    def unfold_quantifiers(expr : Expr) : {Expr, Bool}
      case expr
      when And
        r = unfold_quantifiers(expr.left)
        if r[1]
          {And.new(r[0], expr.right), true}
        else
          r = unfold_quantifiers(expr.right)
          {And.new(expr.left, r[0]), r[1]}
        end
      when Exists
        {Or.from_list(unfold_all_exprs(expr)), true}
      when Forall
        {And.from_list(unfold_all_exprs(expr)), true}
      else
        {expr, false}
      end
    end

    private def unfold_all_exprs(expr : Exists | Forall) : Array(Expr)
      @const_collection.select do |const, type|
        type == expr.var_type
      end.keys.map do |const|
        Appl.new(Lambda.new(expr.var, expr.var_type, expr.expr), const).as(Expr)
      end
    end

    def unfold_const(expr : Expr) : {Expr, Bool}
      case expr
      when And
        r = unfold_const(expr.left)
        if r[1]
          {And.new(r[0], expr.right), true}
        else
          r = unfold_const(expr.right)
          {And.new(expr.left, r[0]), r[1]}
        end
      when Not
        r = unfold_const(expr.expr)
        {Not.new(r[0]), r[1]}
      when Appl
        func, arg = expr.func, expr.arg
        case func
        when False
          {False.new, true}
        else
          r = unfold_const(func)
          if r[1]
            {Appl.new(r[0], arg), true}
          else
            r = unfold_const(arg)
            {Appl.new(func, r[0]), r[1]}
          end
        end
      when Const
        if !@const_collection[expr].predicate?
          {expr, false}
        elsif @program.has_key?(expr)
          {@program[expr], true}
        else
          {False.new, true}
        end
      else
        {expr, false}
      end
    end

    def top_down(expr : Expr) : {Expr, Bool}
      case expr
      when And
        r = top_down(expr.left)
        if r[1]
          {And.new(r[0], expr.right), true}
        else
          r = top_down(expr.right)
          {And.new(expr.left, r[0]), r[1]}
        end
      when True, False
        {expr, false}
      else
        unless free_vars?(expr)
          case @top_down.eval(expr)
          when .true?
            {True.new, true}
          when .false?
            {False.new, true}
          else
            {expr, false}
          end
        else
          {expr, false}
        end
      end
    end

    def visualize
      @visualizer.to_json
    end

    private def cache_valid?(exprs : Set(Expr))
      exprs.all? { |expr| cache_valid?(expr) }
    end

    private def cache_valid?(expr : Expr)
      case expr
      when Appl
        cache_valid?(expr.func) && cache_valid?(expr.arg)
      when Not
        cache_valid?(expr.expr)
      when Var, Eq
        true
      when Const
        @const_collection.has_key?(expr)
      else
        false
      end
    end

    private def conjuncts(expr : Expr) : Array(Expr)
      Array(Expr).new.tap do |list|
        collect_conjuncts(expr, list)
      end
    end

    private def collect_conjuncts(expr : Expr, list : Array(Expr))
      case expr
      when And
        collect_conjuncts(expr.left, list)
        collect_conjuncts(expr.right, list)
      else
        list << expr
      end
    end

    private def consistent?(exprs : Enumerable(Expr))
      positive = Array(Expr).new
      negative = Array(Expr).new
      exprs.each do |expr|
        if expr.is_a?(Not)
          negative << expr.expr
        else
          positive << expr
        end
      end
      (positive & negative).empty?
    end

    protected def self.name
      "dnf"
    end
  end
end

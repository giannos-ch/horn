require "./strategy"
require "../expressions/*"
require "../program"
require "../const_collection"
require "./ht/interpretation"
require "./ht/logic"
require "../types/*"
require "../values/*"

module Horn
  module Strategies
    class HT < Strategy
      include Horn::Expressions
      include Horn::Values

      @program : Program
      @const_collection : ConstCollection

      def initialize(@program, @const_collection)
      end

      def solve(&block : Solution -> Nil)
        @program.rules.each do |head, body|
          if type = @const_collection[head]?
            assign_types(body, type)
          end
        end

        i_domain = @const_collection.select { |_, t| t.is_a?(Types::I) }.keys
        target_consts = @const_collection.reject { |_, t| t.is_a?(Types::I) }

        target_consts_list = target_consts.keys
        target_types_list = target_consts.values

        type_domains = Hash(Type, Array(Value | Expressions::Const)).new

        all_types = Set(Type).new
        all_types.concat(target_types_list)
        @program.rules.each do |head, body|
          collect_types(body, all_types)
        end
        @program.queries.each do |query|
          collect_types(query, all_types)
        end

        all_types.each do |type|
          get_domain(type, i_domain, type_domains)
        end

        interpretations = generate_all_interpretations(target_consts_list, type_domains)

        models = interpretations.select { |interp| is_model?(interp) }

        total_models = models.select { |interp| Logic.is_total?(interp) }

        total_models.each do |m|
          yield m unless models.any? { |other| other != m && other.ht_le(m) }
        end
      end

      private def collect_types(expr : Expr, types : Set(Type))
        case expr
        when Lambda
          if t = expr.param_type
            types << t
          end
          collect_types(expr.body, types)
        when Exists
          if t = expr.var_type
            types << t
          end
          collect_types(expr.expr, types)
        when Forall
          if t = expr.var_type
            types << t
          end
          collect_types(expr.expr, types)
        when Appl
          collect_types(expr.func, types)
          collect_types(expr.arg, types)
        when And
          collect_types(expr.left, types)
          collect_types(expr.right, types)
        when Or
          collect_types(expr.left, types)
          collect_types(expr.right, types)
        when Not
          collect_types(expr.expr, types)
        end
      end

      private def get_domain(type : Type, i_domain, domains) : Array(Value | Expressions::Const)
        return domains[type] if domains.has_key?(type)

        case type
        when Types::I
          domains[type] = i_domain.map { |c| c.as(Value | Expressions::Const) }
        when Types::O
          domains[type] = [Values::False.new, Values::TStar.new, Values::True.new].map { |v| v.as(Value | Expressions::Const) }
        when Types::Arrow
          left_domain = get_domain(type.left, i_domain, domains)
          right_domain = get_domain(type.right, i_domain, domains)

          all_maps = generate_all_maps(left_domain, right_domain)

          monotone_maps = all_maps.select do |m|
            is_monotone?(m, left_domain)
          end
          domains[type] = monotone_maps.map { |m| m.as(Value | Expressions::Const) }
        else
          raise "Unknown type: #{type.class}"
        end
        domains[type]
      end

      private def generate_all_maps(domain_in, domain_out) : Array(Values::Map)
        return [Values::Map.new(Hash(Expr | Value, Value).new)] if domain_in.empty?

        res = Array(Hash(Expr | Value, Value)).new
        res << Hash(Expr | Value, Value).new

        domain_in.each do |input|
          new_res = Array(Hash(Expr | Value, Value)).new
          res.each do |mapping|
            domain_out.each do |output|
              new_mapping = mapping.dup
              new_mapping[input.as(Expr | Value)] = output.as(Value)
              new_res << new_mapping
            end
          end
          res = new_res
        end

        res.map { |m| Values::Map.new(m) }
      end

      private def is_monotone?(m : Values::Map, domain_in)
        domain_in.each do |x|
          domain_in.each do |y|
            if Logic.ht_le(x, y)
              unless Logic.ht_le(m.values[x], m.values[y])
                return false
              end
            end
          end
        end
        true
      end

      private def generate_all_interpretations(consts, domains) : Array(Interpretation)
        return [Interpretation.new(Hash(Expressions::Const, Value).new)] if consts.empty?

        res = Array(Hash(Expressions::Const, Value)).new
        res << Hash(Expressions::Const, Value).new

        consts.each do |const|
          type = @const_collection[const]
          domain = domains[type]
          new_res = Array(Hash(Expressions::Const, Value)).new
          res.each do |mapping|
            domain.each do |val|
              new_mapping = mapping.dup
              new_mapping[const] = val.as(Value)
              new_res << new_mapping
            end
          end
          res = new_res
        end
        res.map { |m| Interpretation.new(m) }
      end

      private def is_model?(interp : Interpretation)
        @program.rules.each do |head, body|
          v_head = eval_expr(head, interp, Hash(Var, Value | Expressions::Const).new)
          v_body = eval_expr(body, interp, Hash(Var, Value | Expressions::Const).new)
          unless Logic.truth_le(v_body, v_head) # Head >= Body
            return false
          end
        end
        @program.queries.each do |query|
          v_query = eval_expr(query, interp, Hash(Var, Value | Expressions::Const).new)
          return false unless v_query == Values::True.new
        end
        true
      end

      private def eval_expr(expr : Expr, interp : Interpretation, env : Hash(Var, Value | Expressions::Const)) : Value | Expressions::Const
        case expr
        when Horn::Expressions::True
          Values::True.new
        when Horn::Expressions::False
          Values::False.new
        when Const
          if @const_collection[expr].is_a?(Types::I)
            expr
          else
            interp[expr]
          end
        when Var
          env[expr]
        when Not
          v = eval_expr(expr.expr, interp, env)
          truth_not(v)
        when And
          v1 = eval_expr(expr.left, interp, env)
          v2 = eval_expr(expr.right, interp, env)
          truth_min(v1, v2)
        when Or
          v1 = eval_expr(expr.left, interp, env)
          v2 = eval_expr(expr.right, interp, env)
          truth_max(v1, v2)
        when Appl
          f = eval_expr(expr.func, interp, env).as(Values::Map)
          a = eval_expr(expr.arg, interp, env)
          f.values[a.as(Expr | Value)]
        when Lambda
          i_domain = @const_collection.select { |_, t| t.is_a?(Types::I) }.keys
          type_domains = Hash(Type, Array(Value | Expressions::Const)).new
          domain_in = get_domain(expr.param_type.not_nil!, i_domain, type_domains)

          mapping = Hash(Expr | Value, Value).new
          domain_in.each do |val|
            new_env = env.dup
            new_env[expr.param] = val
            mapping[val.as(Expr | Value)] = eval_expr(expr.body, interp, new_env).as(Value)
          end
          Values::Map.new(mapping)
        when Exists
          i_domain = @const_collection.select { |_, t| t.is_a?(Types::I) }.keys
          type_domains = Hash(Type, Array(Value | Expressions::Const)).new
          domain = get_domain(expr.var_type, i_domain, type_domains)

          results = domain.map do |val|
            new_env = env.dup
            new_env[expr.var] = val
            eval_expr(expr.expr, interp, new_env).as(Value)
          end
          results.reduce { |acc, v| truth_max(acc, v).as(Value) }
        when Forall
          i_domain = @const_collection.select { |_, t| t.is_a?(Types::I) }.keys
          type_domains = Hash(Type, Array(Value | Expressions::Const)).new
          domain = get_domain(expr.var_type, i_domain, type_domains)

          results = domain.map do |val|
            new_env = env.dup
            new_env[expr.var] = val
            eval_expr(expr.expr, interp, new_env).as(Value)
          end
          results.reduce { |acc, v| truth_min(acc, v).as(Value) }
        when Eq
          v1 = eval_expr(expr.left, interp, env)
          v2 = eval_expr(expr.right, interp, env)
          v1 == v2 ? Values::True.new : Values::False.new
        else
          raise "Unsupported expression in HT: #{expr.class}"
        end
      end

      private def truth_not(v)
        case v
        when Values::False
          Values::True.new
        when Values::True, Values::TStar
          Values::False.new
        when Values::Map
          mapping = Hash(Expr | Value, Value).new
          v.values.each do |arg, val|
            mapping[arg] = truth_not(val).as(Value)
          end
          Values::Map.new(mapping)
        else
          v
        end
      end

      private def truth_min(v1, v2)
        case v1
        when Values::Map
          v2 = v2.as(Values::Map)
          mapping = Hash(Expr | Value, Value).new
          v1.values.each do |arg, val1|
            mapping[arg] = truth_min(val1, v2.values[arg]).as(Value)
          end
          Values::Map.new(mapping)
        else
          if Logic.truth_le(v1, v2)
            v1
          else
            v2
          end
        end
      end

      private def truth_max(v1, v2)
        case v1
        when Values::Map
          v2 = v2.as(Values::Map)
          mapping = Hash(Expr | Value, Value).new
          v1.values.each do |arg, val1|
            mapping[arg] = truth_max(val1, v2.values[arg]).as(Value)
          end
          Values::Map.new(mapping)
        else
          if Logic.truth_le(v1, v2)
            v2
          else
            v1
          end
        end
      end

      private def assign_types(expr : Expr, type : Type)
        case expr
        when Lambda
          if type.is_a?(Types::Arrow)
            expr.param_type ||= type.left
            assign_types(expr.body, type.right)
          end
        when Or
          assign_types(expr.left, type)
          assign_types(expr.right, type)
        when And
          assign_types(expr.left, type)
          assign_types(expr.right, type)
        end
      end

      protected def self.name
        "ht"
      end
    end
  end
end

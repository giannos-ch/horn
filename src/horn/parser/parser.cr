require "../const_collection"
require "../expressions/*"
require "../program"
require "./expression_parser"
require "./ts_parser"
require "./type_parser"

module Horn
  class Parser
    include Expressions

    getter program = Program.new
    getter const_collection = ConstCollection.new

    @ts_parser : TSParser
    @type_parser : TypeParser
    @expression_parser : ExpressionParser

    def initialize(@filename : String)
      source = File.read(@filename)
      @ts_parser = TSParser.new(source, @filename)
      @type_parser = TypeParser.new(@ts_parser)
      @expression_parser = ExpressionParser.new(@ts_parser, @type_parser, @const_collection)
    end

    def parse
      root = @ts_parser.parse

      parse_source(root)
    end

    private def parse_source(node)
      node.children.each do |sentence_node|
        parse_typing_declaration(sentence_node) if sentence_node.type == "typing_declaration"
      end
      node.children.each do |sentence_node|
        case sentence_node.type
        when "clause"
          parse_clause(sentence_node)
        when "fact"
          parse_fact(sentence_node)
        when "query"
          parse_query(sentence_node)
        end
      end
    end

    private def parse_typing_declaration(node)
      type = @type_parser.parse(node.children[-1])
      node.children[0...-1].each do |const_node|
        const = @expression_parser.parse_const(const_node, skip_validation = true)
        @ts_parser.raise_error(const_node, "Duplicate definition.") if @const_collection.has_key?(const)
        @const_collection[const] = type
      end
    end

    private def parse_clause(node)
      body = @expression_parser.parse(node.children[-1])
      add_to_program(parse_head(node.children[0...-1], body))
    end

    private def parse_fact(node)
      add_to_program(parse_head(node.children, nil))
    end

    private def parse_query(node)
      @program.queries << @expression_parser.parse(node.children[0])
    end

    private def parse_head(nodes, parsed_body : Expr?)
      pred = @expression_parser.parse_predicate(nodes[0])
      vars = Array(Var).new
      argument_constraints = Array(Expr).new
      nodes[1...].each do |arg_node|
        case arg_node.type
        when "var"
          var = @expression_parser.parse_var(arg_node)
          if vars.includes?(var)
            var_original = var
            while vars.includes?(var)
              var = Var.new(var.name + '\'')
            end
            argument_constraints << Eq.new(var_original, var)
          end
          vars << var
        when "const"
          const = @expression_parser.parse_const(arg_node)
          var_name = const.name
          while vars.includes?(Var.new(var_name))
            var_name += '\''
          end
          var = Var.new(var_name)
          argument_constraints << Eq.new(var, const)
          vars << var
        else
          @ts_parser.raise_error(arg_node, "Expected an argument.")
        end
      end

      body = argument_constraints
      body << parsed_body if parsed_body
      body << True.new if body.empty?
      parsed_body = And.from_list(body)

      vars.reverse.each do |var|
        parsed_body = Lambda.new(var, nil, parsed_body)
      end

      {pred, parsed_body}
    end

    private def add_to_program(clause : {Expressions::Const, Expr})
      head, body = clause
      if @program.rules.has_key?(head)
        @program.rules[head] = Or.new(@program.rules[head], body)
      else
        @program.rules[head] = body
      end
    end
  end
end

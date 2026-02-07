require "option_parser"

require "./horn/parser/parser"
require "./horn/strategies/top_down"
require "./horn/strategies/dnf_transformer"

module Horn
  VERSION = "0.1.0"
  filename = nil
  verbose = false
  strategy_class = TopDown

  options_parser = OptionParser.parse do |options_parser|
    options_parser.banner = "Usage: horn [options]"

    options_parser.on "-h", "--help", "Show this help" do
      puts options_parser
      exit
    end

    options_parser.on "--version", "Show version" do
      puts "HORN v#{VERSION}"
      exit
    end

    options_parser.on "-f FILE", "--file=FILE", "HORN file" do |f|
      filename = f
    end

    options_parser.on "-v", "--verbose", "Verbose mode" do
      verbose = true
    end

    options_parser.on "-s", "--strategy=STRATEGY", "Strategy: valid values are 'top_down'(default) and 'dnf'" do |s|
      strategy_class = Strategy.with_name(s)
      if strategy_class.nil?
        puts "Invalid strategy: #{s}"
        puts options_parser
        exit(1)
      end
      strategy_class = strategy_class.not_nil!
    end

    options_parser.invalid_option do |option|
      puts "Invalid option: #{option}"
      puts options_parser
      exit(1)
    end
  end

  if filename.nil?
    puts options_parser
    exit(1)
  end

  parser = Parser.new(filename.not_nil!)

  begin
    parser.parse
  rescue e
    puts e.message
    exit(2)
  end

  if verbose
    puts "Program rules:"
    puts parser.program.rules.to_pretty_json
    puts "Const collection:"
    puts parser.const_collection.to_pretty_json
    puts "Queries:"
    puts parser.program.queries.to_json
    puts "Run:"
  end

  strategy = strategy_class.not_nil!.new(parser.program, parser.const_collection)

  begin
    strategy.solve do |query_and_result|
      query, result = query_and_result
      puts "#{query} =>"
      if result.is_a?(Enumerable)
        puts result.join(", ")
      else
        puts result
      end
    end
  rescue e
    puts e.message
    if verbose
      puts "Evaluation graph:"
      puts strategy.visualize
    end
    exit(2)
  end

  if verbose
    puts "Evaluation graph:"
    puts strategy.visualize
  end
end

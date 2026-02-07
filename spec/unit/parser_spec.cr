require "../../src/horn/parser/parser"

require "../spec_helper"

module Horn
  describe Parser do
    it "parses" do
      parser = Parser.new("#{__DIR__}/../fixtures/program.horn")
      parser.parse
      parser.program.rules.size.should eq(2)
      parser.const_collection.size.should eq(4)
      parser.program.queries.size.should eq(1)
    end

    it "parses free variables" do
      parser = Parser.new("#{__DIR__}/../fixtures/equals.horn")
      parser.parse
      parser.program.rules.has_key?(Expressions::Const.new("equals")).should be_true
      parser.const_collection.has_key?(Expressions::Const.new("p")).should be_true
      parser.program.queries.size.should eq(1)
      parser.program.queries[0].should eq(
        Expressions::Appl.from_list([Expressions::Const.new("equals"), Expressions::Const.new("p"), Expressions::Var.new("Q_")])
      )
    end
  end
end

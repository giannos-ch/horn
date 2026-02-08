require "../../spec_helper"
require "../../../src/horn/strategies/ht"
require "../../../src/horn/parser/parser"

describe Horn::Strategies::HT do
  it "yields 4 correct interpretations for Example 3.2 (ho-choice.horn)" do
    parser = Horn::Parser.new("spec/fixtures/ho-choice.horn")
    parser.parse

    strategy = Horn::Strategies::HT.new(parser.program, parser.const_collection)

    interpretations = [] of Horn::Strategies::HT::Interpretation
    strategy.solve do |interpretation|
      interpretations << interpretation.as(Horn::Strategies::HT::Interpretation)
    end

    p_interpretations = interpretations.map do |interp|
      p_const = Horn::Expressions::Const.new("p")
      interp[p_const].to_s
    end.uniq

    p_interpretations.size.should eq(4)

    expected = [
      "{F => F, T* => F, T => F}",
      "{F => T, T* => F, T => F}",
      "{F => F, T* => T, T => T}",
      "{F => T, T* => T, T => T}",
    ]

    expected.each do |exp|
      p_interpretations.should contain(exp)
    end
  end
end

require "../../../src/horn/strategies/dnf_transformer"

require "../../spec_helper"

module Horn
  include Expressions

  p = Program.new
  p.rules.merge!({
    Const.new("p_true")  => Expressions::True.new,
    Const.new("p_false") => Expressions::False.new,
    Const.new("p_a")     => Lambda.new(Var.new("X"), Types::I.new, Eq.new(Var.new("X"), Const.new("a"))),
    Const.new("p_p_a")   => Lambda.new(Var.new("P"), Types::Arrow.new(Types::I.new, Types::O.new),
      Appl.new(Var.new("P"), Const.new("a"))),
  })

  const_collection = {
    Const.new("p_true")  => Types::O.new,
    Const.new("p_false") => Types::O.new,
    Const.new("p_a")     => Types::Arrow.new(Types::I.new, Types::O.new),
    Const.new("p_p_a")   => Types::Arrow.new(Types::Arrow.new(Types::I.new, Types::O.new), Types::O.new),
    Const.new("a")       => Types::I.new,
  }

  strategy = DNFTransformer.new(p, const_collection)

  describe DNFTransformer do
    it "evals" do
      strategy.eval(Const.new("p_true")).should eq(Expressions::True.new)
      strategy.eval(Const.new("p_false")).should eq(Expressions::False.new)
      strategy.eval(Appl.new(Const.new("p_a"), Const.new("a"))).should eq(Expressions::True.new)
      strategy.eval(Appl.new(Const.new("p_a"), Var.new("X_"))).is_a?(Expressions::Eq).should be_true
    end

    it "runs" do
      strategy.run(Const.new("p_true")) do |result|
        result.should eq([Expressions::True.new].to_set)
      end
      strategy.run(Appl.new(Const.new("p_a"), Var.new("X_"))) do |result|
        result.should eq([Expressions::Eq.new(Var.new("X_"), Const.new("a"))].to_set)
      end
      strategy.run(Appl.new(Const.new("p_p_a"), Var.new("P_"))) do |result|
        result.should eq([Appl.new(Var.new("P_"), Const.new("a"))].to_set)
      end
    end
  end
end

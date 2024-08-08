require "ruby-zint"

module Zint
  class GS1128A < Code128
    FNC1 = "\xc1"
    def initialize(value:, **)
      super(**, value: FNC1 + value)
    end
  end

  class GS1128B < Code128
    FNC1 = "\xc1"
    def initialize(value:, **)
      super(**, value: FNC1 + value)
    end
  end

  class GS1128C < Code128
    FNC1 = "\xc1"
    def initialize(value:, **)
      super(**, value: FNC1 + value)
    end
  end
end

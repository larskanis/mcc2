require "barby"

module Barby
  class GS1128A < Code128
    def initialize(data)
      super(data, "A")
    end

    def data
      FNC1 + super
    end
  end

  class GS1128B < Code128
    def initialize(data)
      super(data, "B")
    end

    def data
      FNC1 + super
    end
  end

  class GS1128C < Code128
    def initialize(data)
      super(data, "C")
    end

    def data
      FNC1 + super
    end
  end
end

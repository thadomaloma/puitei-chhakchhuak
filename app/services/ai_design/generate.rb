module AiDesign
  class Generate
    def initialize(shop:, provider: DisabledProvider.new)
      @shop = shop
      @provider = provider
    end

    def call(request)
      provider.submit(request)
    end

    private

    attr_reader :shop, :provider
  end
end

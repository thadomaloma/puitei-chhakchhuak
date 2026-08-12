module AiDesign
  class DisabledProvider < Provider
    def submit(_request)
      raise Unavailable, "AI Design Studio is not available yet"
    end
  end
end

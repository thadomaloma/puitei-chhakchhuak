module AiDesign
  class Provider
    Result = Data.define(:provider_request_id, :image_io, :content_type, :metadata)

    def submit(_request)
      raise NotImplementedError, "AI design provider is not configured"
    end
  end
end

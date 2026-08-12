class BusinessAuditEvent < ApplicationRecord
  belongs_to :shop, optional: true
  belongs_to :actor, class_name: "User", optional: true
  belongs_to :auditable, polymorphic: true, optional: true

  validates :action, :occurred_at, presence: true
  validates :request_id, :ip_address, length: { maximum: 255 }, allow_blank: true
  validates :user_agent, length: { maximum: 500 }, allow_blank: true
  validates :reason, length: { maximum: 1_000 }, allow_blank: true

  before_validation :sanitize_event_data

  scope :recent_first, -> { order(occurred_at: :desc, id: :desc) }

  def self.record!(action:, shop: nil, actor: nil, auditable: nil, metadata: {}, reason: nil, request: nil)
    create!(
      action: action,
      shop: shop,
      actor: actor,
      auditable: auditable,
      metadata: metadata,
      reason: reason,
      request_id: request&.request_id,
      ip_address: request&.remote_ip,
      user_agent: request&.user_agent,
      occurred_at: Time.current
    )
  end

  def readonly?
    persisted?
  end

  private

  SENSITIVE_KEY = /password|token|secret|authorization|signature|credential|cvv|card_number/i

  def sanitize_event_data
    self.reason = reason.to_s.strip.presence
    self.request_id = request_id.to_s.first(255).presence
    self.ip_address = ip_address.to_s.first(255).presence
    self.user_agent = user_agent.to_s.first(500).presence
    self.metadata = redact(metadata)
  end

  def redact(value)
    case value
    when Hash
      value.to_h.each_with_object({}) do |(key, item), sanitized|
        string_key = key.to_s
        sanitized[string_key] = string_key.match?(SENSITIVE_KEY) ? "[REDACTED]" : redact(item)
      end
    when Array
      value.map { |item| redact(item) }
    else
      value
    end
  end
end

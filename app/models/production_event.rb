class ProductionEvent < ApplicationRecord
  tenant_owned_through :production_task
  EVENT_TYPES = %w[claimed assigned started completed skipped reopened].freeze

  belongs_to :production_task, inverse_of: :production_events
  belongs_to :actor, class_name: "User", inverse_of: :production_events

  validates :event_type, inclusion: { in: EVENT_TYPES }

  def readonly?
    persisted?
  end
end

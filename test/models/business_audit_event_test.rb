require "test_helper"

class BusinessAuditEventTest < ActiveSupport::TestCase
  test "events redact sensitive metadata and are immutable" do
    event = BusinessAuditEvent.record!(
      action: "business.security_test",
      actor: users(:owner),
      auditable: users(:manager),
      metadata: { token: "secret-token", nested: { password: "secret", safe: "visible" } }
    )

    assert_equal "[REDACTED]", event.metadata.fetch("token")
    assert_equal "[REDACTED]", event.metadata.dig("nested", "password")
    assert_equal "visible", event.metadata.dig("nested", "safe")
    assert event.readonly?
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.update!(action: "changed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { event.destroy! }
  end
end

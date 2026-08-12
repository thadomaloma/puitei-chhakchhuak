require "test_helper"

class ProductionReadinessTest < ActiveSupport::TestCase
  COMPLETE_ENVIRONMENT = {
    "APP_HOST" => "puitei.example",
    "MAILER_FROM" => "notifications@puitei.example",
    "SMTP_ADDRESS" => "smtp.example",
    "ACTIVE_STORAGE_SERVICE" => "local",
    "DATABASE_URL" => "postgres://example",
    "SECRET_KEY_BASE" => "secret"
  }.freeze

  test "accepts a complete production environment" do
    assert ProductionReadiness.check_environment!(COMPLETE_ENVIRONMENT)
  end

  test "reports every missing production dependency" do
    error = assert_raises(RuntimeError) { ProductionReadiness.check_environment!({}) }

    ProductionReadiness::REQUIRED_ENVIRONMENT.each { |name| assert_includes error.message, name }
    assert_includes error.message, "DATABASE_URL or TAILOR_FLOW_DATABASE_PASSWORD"
    assert_includes error.message, "RAILS_MASTER_KEY or SECRET_KEY_BASE"
  end

  test "accepts database password and master key alternatives" do
    environment = COMPLETE_ENVIRONMENT.except("DATABASE_URL", "SECRET_KEY_BASE").merge(
      "TAILOR_FLOW_DATABASE_PASSWORD" => "database-secret", "RAILS_MASTER_KEY" => "master-key"
    )

    assert_empty ProductionReadiness.missing_environment(environment)
  end
end

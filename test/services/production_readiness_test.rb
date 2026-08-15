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

  test "requires Railway bucket settings when railway storage is selected" do
    environment = COMPLETE_ENVIRONMENT.merge("ACTIVE_STORAGE_SERVICE" => "railway")

    error = assert_raises(RuntimeError) { ProductionReadiness.check_environment!(environment) }

    ProductionReadiness::RAILWAY_STORAGE_ENVIRONMENT.each { |name| assert_includes error.message, name }
  end

  test "accepts a complete Railway bucket configuration" do
    environment = COMPLETE_ENVIRONMENT.merge(
      "ACTIVE_STORAGE_SERVICE" => "railway",
      "AWS_ENDPOINT_URL" => "https://storage.railway.app",
      "AWS_ACCESS_KEY_ID" => "access-key",
      "AWS_SECRET_ACCESS_KEY" => "secret-key",
      "AWS_S3_BUCKET_NAME" => "puitei-uploads-abc123",
      "AWS_DEFAULT_REGION" => "auto"
    )

    assert_empty ProductionReadiness.missing_environment(environment)
  end

  test "rejects ephemeral local uploads on Railway" do
    environment = COMPLETE_ENVIRONMENT.merge("RAILWAY_SERVICE_ID" => "puitei-service")

    assert_includes ProductionReadiness.missing_environment(environment), "non-local ACTIVE_STORAGE_SERVICE on Railway"
  end
end

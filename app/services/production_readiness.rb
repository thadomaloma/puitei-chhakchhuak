class ProductionReadiness
  REQUIRED_ENVIRONMENT = %w[APP_HOST MAILER_FROM SMTP_ADDRESS ACTIVE_STORAGE_SERVICE].freeze

  def self.missing_environment(environment = ENV)
    missing = REQUIRED_ENVIRONMENT.select { |name| environment[name].blank? }
    missing << "DATABASE_URL or TAILOR_FLOW_DATABASE_PASSWORD" unless database_configured?(environment)
    missing << "RAILS_MASTER_KEY or SECRET_KEY_BASE" unless secret_configured?(environment)
    missing
  end

  def self.check_environment!(environment = ENV)
    missing = missing_environment(environment)
    return true if missing.empty?

    raise "Production configuration is incomplete: #{missing.join(', ')}"
  end

  def self.check_database!
    ActiveRecord::Base.connection.execute("SELECT 1")
    true
  end

  def self.check_storage!
    ActiveStorage::Blob.service
    true
  rescue KeyError => error
    raise "Active Storage service is not configured: #{error.message}"
  end

  def self.database_configured?(environment)
    environment["DATABASE_URL"].present? || environment["TAILOR_FLOW_DATABASE_PASSWORD"].present?
  end
  private_class_method :database_configured?

  def self.secret_configured?(environment)
    environment["RAILS_MASTER_KEY"].present? || environment["SECRET_KEY_BASE"].present?
  end
  private_class_method :secret_configured?
end

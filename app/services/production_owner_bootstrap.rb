class ProductionOwnerBootstrap
  Result = Data.define(:shop, :branch, :owner, :created)

  REQUIRED_ENVIRONMENT = %w[BOOTSTRAP_OWNER_EMAIL BOOTSTRAP_OWNER_PASSWORD].freeze
  FORBIDDEN_PASSWORD_FRAGMENTS = %w[dev-2026 password].freeze

  def self.call!(environment = ENV)
    new(environment).call!
  end

  def initialize(environment)
    @environment = environment
  end

  def call!
    validate_environment!

    ApplicationRecord.transaction do
      shop = find_or_create_shop!
      existing_owner = shop.owner

      if existing_owner
        return Result.new(shop:, branch: existing_owner.branch, owner: existing_owner, created: false) if
          existing_owner.email.casecmp?(owner_email)

        raise "The production shop already has an active owner; no account was changed."
      end

      if User.where("LOWER(email) = ?", owner_email.downcase).exists?
        raise "An account with BOOTSTRAP_OWNER_EMAIL already exists; no account was changed."
      end

      branch = find_or_create_branch!(shop)
      owner = User.create!(
        branch:,
        name: environment.fetch("BOOTSTRAP_OWNER_NAME", "Business Owner").strip,
        email: owner_email,
        password: owner_password,
        password_confirmation: owner_password,
        role: :owner,
        job_title: "Owner",
        pay_basis: :monthly_salary,
        pay_rate: 0,
        active: true,
        joined_on: Date.current,
        terms_accepted_at: Time.current
      )

      Membership.create!(
        shop:,
        branch:,
        user: owner,
        role: :owner,
        employee_code: owner.employee_code,
        job_title: "Owner",
        pay_basis: :monthly_salary,
        pay_rate: 0,
        active: true,
        joined_on: owner.joined_on,
        accepted_at: Time.current
      )

      shop.update!(created_by: owner, onboarding_completed_at: Time.current)
      Result.new(shop:, branch:, owner:, created: true)
    end
  end

  private

  attr_reader :environment

  def find_or_create_shop!
    Shop.find_or_create_by!(slug: Shop::CANONICAL_SLUG) do |shop|
      shop.name = environment.fetch("BOOTSTRAP_SHOP_NAME", "Puitei Chhakchhuak")
      shop.country = environment.fetch("BOOTSTRAP_COUNTRY", "India")
      shop.active = true
    end
  end

  def find_or_create_branch!(shop)
    code = environment.fetch("BOOTSTRAP_BRANCH_CODE", "MAIN").strip.upcase

    shop.branches.find_or_create_by!(code:) do |branch|
      branch.name = environment.fetch("BOOTSTRAP_BRANCH_NAME", "Main Studio")
      branch.locale = environment.fetch("BOOTSTRAP_LOCALE", "en")
      branch.time_zone = environment.fetch("BOOTSTRAP_TIME_ZONE", "Asia/Kolkata")
      branch.active = true
    end
  end

  def validate_environment!
    missing = REQUIRED_ENVIRONMENT.select { |name| environment[name].blank? }
    raise "Missing bootstrap environment: #{missing.join(', ')}" if missing.any?

    unless owner_email.match?(Devise.email_regexp)
      raise "BOOTSTRAP_OWNER_EMAIL is not a valid email address."
    end

    password = owner_password
    password_is_strong = password.length >= 16 && password.match?(/[a-z]/) && password.match?(/[A-Z]/) &&
      password.match?(/\d/) && password.match?(/[^A-Za-z0-9]/)
    forbidden = FORBIDDEN_PASSWORD_FRAGMENTS.any? { |fragment| password.downcase.include?(fragment) }

    return if password_is_strong && !forbidden

    raise "BOOTSTRAP_OWNER_PASSWORD must contain at least 16 characters, upper/lowercase letters, a number, and a symbol; development passwords are forbidden."
  end

  def owner_email
    @owner_email ||= environment.fetch("BOOTSTRAP_OWNER_EMAIL").strip.downcase
  end

  def owner_password
    environment.fetch("BOOTSTRAP_OWNER_PASSWORD")
  end
end

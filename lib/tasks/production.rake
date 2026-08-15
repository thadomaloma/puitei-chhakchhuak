namespace :production do
  desc "Fail when required production environment variables are missing"
  task check_environment: :environment do
    ProductionReadiness.check_environment!
    puts "Production environment configuration is complete."
  end

  desc "Check environment, database connectivity, and Active Storage configuration"
  task readiness: :environment do
    ProductionReadiness.check_environment!
    ProductionReadiness.check_database!
    ProductionReadiness.check_storage!
    puts "Puitei Chhakchhuak is ready to serve traffic."
  end

  desc "Create the first production owner from one-time environment variables"
  task bootstrap_owner: :environment do
    unless Rails.env.production?
      abort "production:bootstrap_owner is restricted to RAILS_ENV=production."
    end

    result = ProductionOwnerBootstrap.call!
    action = result.created ? "created" : "already exists"
    puts "Production owner #{action}: #{result.owner.email} (#{result.branch.name})."
    puts "No password was printed. Remove or rotate the bootstrap password secret now."
  end
end

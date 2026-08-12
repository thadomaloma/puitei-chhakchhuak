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
end

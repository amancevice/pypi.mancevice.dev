require "rake/clean"
CLEAN.include ".terraform/terraform.zip"
CLOBBER.include ".terraform"
task :default => %i[terraform:plan]

PYPI_USER  = ENV["PYPI_USER"]
PYPI_PASS  = ENV["PYPI_PASS"]
PYPI_HOST  = "pypi.mancevice.dev"
PYPI_INDEX = "https://#{PYPI_USER}:#{PYPI_PASS}@#{PYPI_HOST}/simple/"

namespace :pip do
  desc "Get pip HTTP response"
  task :get, %i[pip] do |t,args|
    sh "curl -L '#{PYPI_INDEX}#{args.pip}'"
    puts
  end

  desc "Search pypi.mancevice.dev"
  task :search, %i[pip] do |t,args|
    sh "pip search #{args.pip} -i #{PYPI_INDEX}"
    puts
  end
end

namespace :s3 do
  desc "List packages on S3"
  task :ls do
    sh "aws s3 ls s3://#{PYPI_HOST}/ --human-readable --recursive"
  end
end

namespace :terraform do
  directory(".terraform") { sh "terraform init" }

  :".terraform/tfplan.zip".tap do |planfile|
    file planfile => Dir["*.tf", "alexander/*"], order_only: ".terraform" do
      sh "terraform plan -out #{planfile}"
    end

    desc "terraform plan"
    task :plan => planfile

    desc "terraform apply"
    task :apply => planfile do
      sh "terraform apply #{planfile}"
    end
  end
end

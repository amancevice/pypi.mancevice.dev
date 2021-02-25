require "rake/clean"
CLEAN.include ".terraform/terraform.zip"
CLOBBER.include ".terraform", ".terraform.lock.hcl"
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
  task :init => ".terraform"

  directory ".terraform" do
    sh "terraform init"
  end

  ".terraform/tfplan.zip".tap do |planfile|
    desc "terraform plan"
    task :plan => planfile

    desc "terraform apply"
    task :apply => planfile do
      sh "terraform apply #{planfile}"
    end

    file planfile => Dir["*.tf", "alexander/*"], order_only: ".terraform" do |f|
      sh "terraform plan -out #{f.name}"
    end
  end


end

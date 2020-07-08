require "rake/clean"
CLEAN.include ".terraform/terraform.zip"
CLOBBER.include ".terraform"
task :default => %i[plan]

directory(".terraform") { sh "terraform init" }

".terraform/terraform.zip".tap do |planfile|
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

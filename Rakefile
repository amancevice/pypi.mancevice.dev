require "rake/clean"
CLEAN.include ".terraform/terraform.zip"
CLOBBER.include ".terraform"
task :default => %i[terraform:plan]

PYPI_USER  = ENV["PYPI_USER"]
PYPI_PASS  = ENV["PYPI_PASS"]
PYPI_HOST  = "pypi.mancevice.dev"
PYPI_INDEX = "https://#{PYPI_USER}:#{PYPI_PASS}@#{PYPI_HOST}/simple/"

namespace :cognito do
  desc "Create Cognito user"
  task :"create-user", %i[user pass] do |t,args|
    user = args.user || PYPI_USER
    pass = args.pass || PYPI_PASS
    sh <<~EOS
      aws cognito-idp admin-create-user \
      --user-pool-id $(terraform output cognito_user_pool_id) \
      --username #{user} \
      --temporary-password '#{pass}'
    EOS
    sh <<~EOS
      aws cognito-idp initiate-auth \
      --client-id $(terraform output cognito_user_pool_client_id) \
      --auth-flow 'USER_PASSWORD_AUTH' \
      --auth-parameters 'USERNAME=#{user},PASSWORD=#{pass}' \
      --query 'Session' \
      --output text > .session
    EOS
    sh <<~EOS
      aws cognito-idp respond-to-auth-challenge \
      --client-id $(terraform output cognito_user_pool_client_id) \
      --challenge-name 'NEW_PASSWORD_REQUIRED' \
      --challenge-responses 'USERNAME=#{user},NEW_PASSWORD=#{pass}' \
      --session "$(cat .session)"
    EOS
  	rm ".session"
  end

  desc "Delete Cognito user"
  task :"delete-user", %i[user] do |t,args|
    sh <<~EOS
      aws cognito-idp admin-delete-user
      --user-pool-id $(terraform output cognito_user_pool_id) \
      --username #{args.user}
    EOS
  end

  desc "List Cognito users"
  task :"list-users" do
    sh <<~EOS
      aws cognito-idp list-users \
      --user-pool-id $(terraform output cognito_user_pool_id) \
      --query 'Users[].Username' \
      --output text
    EOS
  end
end

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
end

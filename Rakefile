require "dotenv/load"
require "rake/clean"
CLEAN.include ".terraform"
task :default => %i[terraform:plan]

namespace :terraform do
  desc "Run terraform apply"
  task :apply do
    sh %{terraform apply}
  end

  desc "Run terraform plan"
  task :plan => :init do
    sh %{terraform plan}
  end

  task :init => ".terraform"

  namespace :apply do
    desc "Run terraform auto -auto-approve"
    task :auto do
      sh %{terraform apply -auto-approve}
    end
  end

  directory ".terraform" do
    sh %{terraform init}
  end
end

namespace :s3 do
  desc "List S3 contents"
  task :ls do
    sh "aws s3 ls s3://www.brutalismbot.com/"
  end

  desc "Sync local files with S3"
  task :sync do
    sh "aws s3 sync www s3://www.brutalismbot.com/"
  end
end

namespace :cloudfront do
  desc "Invalidate CloudFront cache"
  task :invalidate => %i[terraform:init] do
    sh <<~SH
      terraform output -raw cloudfront_distribution_id \
      | xargs aws cloudfront create-invalidation --paths '/*' --distribution-id \
      | jq
    SH
  end
end

desc "Start local HTTP server"
task :up do
  sh "ruby -run -e httpd www"
end

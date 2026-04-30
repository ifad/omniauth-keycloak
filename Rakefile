# frozen_string_literal: true

require 'bundler/gem_tasks'
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec)

task default: :spec

namespace :spec do
  desc 'Regenerates the RSA keys for the integration tests'
  task :regenerate_key do
    require 'openssl'

    {
      'spec/integration.key' => OpenSSL::PKey::RSA.generate(2048),
      'spec/attacker.key' => OpenSSL::PKey::RSA.generate(2048)
    }.each do |file, key|
      File.open(File.join(__dir__, file), 'w') do |f|
        f.puts <<~TXT
          Auto-generated RSA key for integration tests.

          To regenerate, run:
            rake spec:regenerate_key

          Do not use outside of this project!
          Consider this key compromised!

          #{key.to_pem}
        TXT
      end
    end
  end
end

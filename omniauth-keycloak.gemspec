# frozen_string_literal: true

require File.expand_path('lib/keycloak/version', __dir__)

Gem::Specification.new do |spec|
  spec.name          = 'omniauth-keycloak'
  spec.version       = Omniauth::Keycloak::VERSION
  spec.authors       = ['Cameron Crockett']
  spec.email         = ['cameron.crockett@ccrockett.com']

  spec.description   = 'Omniauth strategy for Keycloak'
  spec.summary       = spec.description
  spec.homepage      = 'https://github.com/ccrockett/omniauth-keycloak'
  spec.license       = 'MIT'

  spec.metadata = {
    'bug_tracker_uri' => 'https://github.com/ccrockett/omniauth-keycloak/issues',
    'changelog_uri' => 'https://github.com/ccrockett/omniauth-keycloak/blob/master/CHANGELOG.md',
    'homepage_uri' => 'https://github.com/ccrockett/omniauth-keycloak',
    'rubygems_mfa_required' => 'true',
    'source_code_uri' => 'https://github.com/ccrockett/omniauth-keycloak'
  }

  spec.files         = Dir['LICENSE.txt', 'README.md', 'CHANGELOG.md', 'lib/**/*.rb', 'bin/console']

  spec.require_paths = ['lib']

  spec.required_rubygems_version = '>= 3.1.2'
  spec.required_ruby_version = '>= 2.6'

  spec.add_dependency 'faraday'
  spec.add_dependency 'json-jwt', '> 1.13.0'
  spec.add_dependency 'omniauth', '>= 2.0'
  spec.add_dependency 'omniauth-oauth2', '>= 1.7', '< 1.9'
end

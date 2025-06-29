# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::KeycloakOpenId do
  let(:body) do
    {
      issuer: 'http://localhost:8080/auth/realms/example-realm',
      authorization_endpoint: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/auth',
      token_endpoint: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/token',
      token_introspection_endpoint: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/token/introspect',
      userinfo_endpoint: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/userinfo',
      end_session_endpoint: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/logout',
      jwks_uri: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/certs',
      check_session_iframe: 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/login-status-iframe.html',
      grant_types_supported: %w[authorization_code implicit refresh_token password client_credentials],
      response_types_supported: ['code', 'none', 'id_token', 'token', 'id_token token', 'code id_token',
                                 'code token', 'code id_token token'],
      subject_types_supported: %w[public pairwise],
      id_token_signing_alg_values_supported: ['RS256'],
      userinfo_signing_alg_values_supported: ['RS256'],
      request_object_signing_alg_values_supported: %w[none RS256],
      response_modes_supported: %w[query fragment form_post],
      registration_endpoint: 'http://localhost:8080/auth/realms/example-realm/clients-registrations/openid-connect',
      token_endpoint_auth_methods_supported: %w[private_key_jwt client_secret_basic client_secret_post],
      token_endpoint_auth_signing_alg_values_supported: ['RS256'],
      claims_supported: %w[sub iss auth_time name given_name family_name preferred_username
                           email],
      claim_types_supported: ['normal'],
      claims_parameter_supported: false,
      scopes_supported: %w[openid offline_access],
      request_parameter_supported: true,
      request_uri_parameter_supported: true
    }
  end

  context 'with client options' do
    subject(:strategy) do
      stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/.well-known/openid-configuration')
        .to_return(status: 200, body: JSON.generate(body), headers: {})
      stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/certs')
        .to_return(status: 404, body: '', headers: {})
      described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                          client_options: { site: 'http://localhost:8080/', realm: 'example-realm' })
    end

    it 'has the correct keycloak token url' do
      strategy.setup_phase
      expect(strategy.token_url).to eq('/auth/realms/example-realm/protocol/openid-connect/token')
    end

    it 'has the correct keycloak authorization url' do
      strategy.setup_phase
      expect(strategy.authorize_url).to eq('/auth/realms/example-realm/protocol/openid-connect/auth')
    end
  end

  describe 'test mode' do
    subject(:strategy) do
      stub_request(:get, config_url)
      described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                          client_options: { site: 'http://localhost:8080/', realm: 'example-realm', base_url: '' })
    end

    let(:config_url) { 'http://localhost:8080/realms/example-realm/.well-known/openid-configuration' }

    before do
      OmniAuth.config.test_mode = true
    end

    after do
      OmniAuth.config.test_mode = false
    end

    it 'does not fetch configuration when in test mode' do
      strategy.setup_phase
      expect(a_request(:get, config_url)).not_to have_been_made
    end
  end

  describe 'client base_url option set' do
    context 'with blank string' do
      subject(:strategy) do
        stub_request(:get, 'http://localhost:8080/realms/example-realm/.well-known/openid-configuration')
          .to_return(status: 200, body: JSON.generate(body.merge(new_body_endpoints)), headers: {})
        stub_request(:get, 'http://localhost:8080/realms/example-realm/protocol/openid-connect/certs')
          .to_return(status: 404, body: '', headers: {})
        described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                            client_options: {
                              site: 'http://localhost:8080/', realm: 'example-realm', base_url: ''
                            })
      end

      let(:new_body_endpoints) do
        {
          authorization_endpoint: 'http://localhost:8080/realms/example-realm/protocol/openid-connect/auth',
          token_endpoint: 'http://localhost:8080/realms/example-realm/protocol/openid-connect/token',
          jwks_uri: 'http://localhost:8080/realms/example-realm/protocol/openid-connect/certs'
        }
      end

      it 'has the correct keycloak token url' do
        strategy.setup_phase
        expect(strategy.token_url).to eq('/realms/example-realm/protocol/openid-connect/token')
      end

      it 'has the correct keycloak authorization url' do
        strategy.setup_phase
        expect(strategy.authorize_url).to eq('/realms/example-realm/protocol/openid-connect/auth')
      end
    end

    context 'with invalid string' do
      subject(:strategy) do
        stub_request(:get, 'http://localhost:8080/realms/example-realm/.well-known/openid-configuration')
          .to_return(status: 200, body: JSON.generate(body), headers: {})
        stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/certs')
          .to_return(status: 404, body: '', headers: {})
        described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                            client_options: {
                              site: 'http://localhost:8080/', realm: 'example-realm', base_url: 'test'
                            })
      end

      it 'raises Configuration Error' do
        expect { strategy.setup_phase }
          .to raise_error(OmniAuth::Strategies::KeycloakOpenId::ConfigurationError)
      end
    end

    context 'with /authorize' do
      subject(:strategy) do
        stub_request(:get, 'http://localhost:8080/authorize/realms/example-realm/.well-known/openid-configuration')
          .to_return(status: 200, body: JSON.generate(body.merge(new_body_endpoints)), headers: {})
        stub_request(:get, 'http://localhost:8080/authorize/realms/example-realm/protocol/openid-connect/certs')
          .to_return(status: 404, body: '', headers: {})
        described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                            client_options: {
                              site: 'http://localhost:8080/', realm: 'example-realm', base_url: '/authorize'
                            })
      end

      let(:new_body_endpoints) do
        {
          authorization_endpoint: 'http://localhost:8080/authorize/realms/example-realm/protocol/openid-connect/auth',
          token_endpoint: 'http://localhost:8080/authorize/realms/example-realm/protocol/openid-connect/token',
          jwks_uri: 'http://localhost:8080/authorize/realms/example-realm/protocol/openid-connect/certs'
        }
      end

      it 'has the correct keycloak token url' do
        strategy.setup_phase
        expect(strategy.token_url).to eq('/authorize/realms/example-realm/protocol/openid-connect/token')
      end

      it 'has the correct keycloak authorization url' do
        strategy.setup_phase
        expect(strategy.authorize_url).to eq('/authorize/realms/example-realm/protocol/openid-connect/auth')
      end
    end
  end

  context 'with client setup with a proc' do
    subject(:strategy) do
      described_class.new('keycloak-openid', setup: proc { throw :setup_proc_was_called })
    end

    it 'calls the proc' do
      expect { strategy.setup_phase }.to throw_symbol :setup_proc_was_called
    end
  end

  describe 'errors processing' do
    context 'when site contains /auth part' do
      subject(:strategy) do
        described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                            client_options: {
                              site: 'http://localhost:8080/auth', realm: 'example-realm', raise_on_failure: true
                            })
      end

      it 'raises Configuration Error' do
        expect { strategy.setup_phase }
          .to raise_error(OmniAuth::Strategies::KeycloakOpenId::ConfigurationError)
      end
    end

    context 'when raise_on_failure option is true' do
      context 'when openid configuration endpoint returns error response' do
        subject(:strategy) do
          stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/.well-known/openid-configuration')
            .to_return(status: 404, body: '', headers: {})
          described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                              client_options: {
                                site: 'http://localhost:8080', realm: 'example-realm', raise_on_failure: true
                              })
        end

        it 'raises Integration Error' do
          expect { strategy.setup_phase }
            .to raise_error(OmniAuth::Strategies::KeycloakOpenId::IntegrationError)
        end
      end

      context 'when certificates endpoint returns error response' do
        subject(:strategy) do
          stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/.well-known/openid-configuration')
            .to_return(status: 200, body: JSON.generate(body), headers: {})
          stub_request(:get, 'http://localhost:8080/auth/realms/example-realm/protocol/openid-connect/certs')
            .to_return(status: 404, body: '', headers: {})
          described_class.new('keycloak-openid', 'Example-Client', 'b53c572b-9f3b-4e79-bf8b-f03c799ba6ec',
                              client_options: {
                                site: 'http://localhost:8080', realm: 'example-realm', raise_on_failure: true
                              })
        end

        it 'raises Integration Error' do
          expect { strategy.setup_phase }
            .to raise_error(OmniAuth::Strategies::KeycloakOpenId::IntegrationError)
        end
      end
    end
  end
end

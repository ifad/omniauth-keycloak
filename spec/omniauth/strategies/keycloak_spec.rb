# frozen_string_literal: true

require 'spec_helper'

RSpec.describe OmniAuth::Strategies::Keycloak do
  let(:body) do
    {
      issuer: 'https://example.org/realms/example-realm',
      authorization_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/auth',
      token_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/token',
      token_introspection_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/token/introspect',
      userinfo_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/userinfo',
      end_session_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/logout',
      jwks_uri: 'https://example.org/realms/example-realm/protocol/openid-connect/certs',
      check_session_iframe: 'https://example.org/realms/example-realm/protocol/openid-connect/login-status-iframe.html',
      grant_types_supported: %w[authorization_code implicit refresh_token password client_credentials],
      response_types_supported: [
        'code', 'none', 'id_token', 'token', 'id_token token', 'code id_token', 'code token', 'code id_token token'
      ],
      subject_types_supported: %w[public pairwise],
      id_token_signing_alg_values_supported: ['RS256'],
      userinfo_signing_alg_values_supported: ['RS256'],
      request_object_signing_alg_values_supported: %w[none RS256],
      response_modes_supported: %w[query fragment form_post],
      registration_endpoint: 'https://example.org/realms/example-realm/clients-registrations/openid-connect',
      token_endpoint_auth_methods_supported: %w[private_key_jwt client_secret_basic client_secret_post],
      token_endpoint_auth_signing_alg_values_supported: ['RS256'],
      claims_supported: %w[sub iss auth_time name given_name family_name preferred_username email],
      claim_types_supported: ['normal'],
      claims_parameter_supported: false,
      scopes_supported: %w[openid offline_access],
      request_parameter_supported: true,
      request_uri_parameter_supported: true
    }
  end

  let(:certificates_body) { { keys: [{ kty: 'RSA' }] } }

  let(:app) { ->(_env) { [200, {}, ['Hello.']] } }

  let(:strategy) do
    described_class.new(
      app, 'client', 'secret',
      client_options: client_options,
      **strategy_options
    )
  end

  let(:client_options) { { site: 'https://example.org/', realm: 'example-realm' } }
  let(:strategy_options) { {} }

  context 'with client options' do
    before do
      stub_request(:get, 'https://example.org/realms/example-realm/.well-known/openid-configuration')
        .to_return(status: 200, body: JSON.generate(body), headers: {})

      stub_request(:get, 'https://example.org/realms/example-realm/protocol/openid-connect/certs')
        .to_return(status: 200, body: JSON.generate(certificates_body), headers: {})

      strategy.setup_phase
    end

    it 'has the correct keycloak token url' do
      expect(strategy.token_url).to eq('/realms/example-realm/protocol/openid-connect/token')
    end

    it 'has the correct keycloak authorization url' do
      expect(strategy.authorize_url).to eq('/realms/example-realm/protocol/openid-connect/auth')
    end

    it 'assigns the certificates' do
      expect(strategy.certs.first['kty']).to eq('RSA')
    end
  end

  context 'when test mode is enabled' do
    let(:config_url) { 'https://example.org/realms/example-realm/.well-known/openid-configuration' }

    before do
      stub_request(:get, config_url)
      OmniAuth.config.test_mode = true
      strategy.setup_phase
    end

    after do
      OmniAuth.config.test_mode = false
    end

    it 'does not fetch configuration' do
      expect(a_request(:get, config_url)).not_to have_been_made
    end
  end

  context 'when base_url option is set' do
    context 'with blank string' do
      let(:client_options) { { site: 'https://example.org/', realm: 'example-realm', base_url: '' } }

      let(:new_body_endpoints) do
        {
          authorization_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/auth',
          token_endpoint: 'https://example.org/realms/example-realm/protocol/openid-connect/token',
          jwks_uri: 'https://example.org/realms/example-realm/protocol/openid-connect/certs'
        }
      end

      before do
        stub_request(:get, 'https://example.org/realms/example-realm/.well-known/openid-configuration')
          .to_return(status: 200, body: JSON.generate(body.merge(new_body_endpoints)), headers: {})

        stub_request(:get, 'https://example.org/realms/example-realm/protocol/openid-connect/certs')
          .to_return(status: 200, body: JSON.generate(certificates_body), headers: {})

        strategy.setup_phase
      end

      it 'has the correct keycloak token url' do
        expect(strategy.token_url).to eq('/realms/example-realm/protocol/openid-connect/token')
      end

      it 'has the correct keycloak authorization url' do
        expect(strategy.authorize_url).to eq('/realms/example-realm/protocol/openid-connect/auth')
      end
    end

    context 'with /authorize' do
      let(:client_options) { { site: 'https://example.org/', realm: 'example-realm', base_url: '/authorize' } }

      let(:new_body_endpoints) do
        {
          authorization_endpoint: 'https://example.org/authorize/realms/example-realm/protocol/openid-connect/auth',
          token_endpoint: 'https://example.org/authorize/realms/example-realm/protocol/openid-connect/token',
          jwks_uri: 'https://example.org/authorize/realms/example-realm/protocol/openid-connect/certs'
        }
      end

      before do
        stub_request(:get, 'https://example.org/authorize/realms/example-realm/.well-known/openid-configuration')
          .to_return(status: 200, body: JSON.generate(body.merge(new_body_endpoints)), headers: {})

        stub_request(:get, 'https://example.org/authorize/realms/example-realm/protocol/openid-connect/certs')
          .to_return(status: 200, body: JSON.generate(certificates_body), headers: {})

        strategy.setup_phase
      end

      it 'has the correct keycloak token url' do
        expect(strategy.token_url).to eq('/authorize/realms/example-realm/protocol/openid-connect/token')
      end

      it 'has the correct keycloak authorization url' do
        expect(strategy.authorize_url).to eq('/authorize/realms/example-realm/protocol/openid-connect/auth')
      end
    end
  end

  context 'with client setup with a proc' do
    let(:strategy) { described_class.new(app, setup: proc { throw :setup_proc_was_called }) }

    it 'calls the proc' do
      expect { strategy.setup_phase }.to throw_symbol :setup_proc_was_called
    end
  end

  describe '#request_phase' do
    let(:strategy_options) { { authorize_options: %i[scope kc_idp_hint] } }

    let(:request) do
      instance_double(
        Rack::Request,
        scheme: 'https', env: {}, url: '', query_string: '',
        params: { 'kc_idp_hint' => 'some-idp' }
      )
    end

    before do
      OmniAuth.config.test_mode = true
      allow(strategy).to receive(:request).and_return(request)
      strategy.request_phase
    end

    after do
      OmniAuth.config.test_mode = false
    end

    it 'merges request params into options' do
      expect(strategy.options[:kc_idp_hint]).to eq('some-idp')
    end
  end

  describe 'errors processing' do
    context 'when site contains /auth part' do
      let(:client_options) { { site: 'https://example.org/auth', realm: 'example-realm', raise_on_failure: true } }

      it 'raises a Configuration Error' do
        expect { strategy.setup_phase }
          .to raise_error(OmniAuth::Strategies::Keycloak::ConfigurationError)
      end
    end

    context 'when raise_on_failure option is true' do
      let(:client_options) { { site: 'https://example.org', realm: 'example-realm', raise_on_failure: true } }

      context 'when openid configuration endpoint returns error response' do
        before do
          stub_request(:get, 'https://example.org/realms/example-realm/.well-known/openid-configuration')
            .to_return(status: 404, body: '', headers: {})
        end

        it 'raises an Integration Error' do
          expect { strategy.setup_phase }
            .to raise_error(OmniAuth::Strategies::Keycloak::IntegrationError)
        end
      end

      context 'when certificates endpoint returns error response' do
        before do
          stub_request(:get, 'https://example.org/realms/example-realm/.well-known/openid-configuration')
            .to_return(status: 200, body: JSON.generate(body), headers: {})

          stub_request(:get, 'https://example.org/realms/example-realm/protocol/openid-connect/certs')
            .to_return(status: 404, body: '', headers: {})
        end

        it 'raises an Integration Error' do
          expect { strategy.setup_phase }
            .to raise_error(OmniAuth::Strategies::Keycloak::IntegrationError)
        end
      end
    end

    context 'with a relative base_url' do
      let(:client_options) { { site: 'https://example.org', realm: 'example-realm', base_url: 'relative-url' } }

      it 'raises a Configuration Error' do
        expect { strategy.setup_phase }
          .to raise_error(OmniAuth::Strategies::Keycloak::ConfigurationError)
      end
    end
  end
end

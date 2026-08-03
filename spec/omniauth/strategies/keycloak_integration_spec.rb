# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'rack/session'
require 'openssl'

# Integration spec for OmniAuth::Strategies::Keycloak.
#
# Unlike the unit spec which stubs HTTP responses with minimal/fake key material,
# this spec uses a real RSA key pair, publishes the corresponding JWKS over
# WebMock, and signs JWTs with the private key.
#
# The strategy is exercised end-to-end through a real Rack middleware stack
# using Rack::Test.
RSpec.describe OmniAuth::Strategies::Keycloak, :integration do
  include Rack::Test::Methods

  let(:key)   { OpenSSL::PKey::RSA.new File.read(File.join(__dir__, '../../integration.key')) }
  let(:jwk)   { JWT::JWK.new(key) }
  let(:realm) { 'test-realm' }
  let(:site)  { 'https://keycloak.example.com' }

  let(:app) do
    client_options = { site: site, realm: realm }

    Rack::Builder.new do
      use Rack::Session::Pool, expire_after: 60
      use OmniAuth::Builder do
        provider :keycloak, 'test-client', 'test-secret',
                 provider_ignores_state: true,
                 client_options: client_options
      end

      run lambda { |env|
        auth = env['omniauth.auth']
        body = auth ? JSON.generate(auth.to_h) : 'OK'
        [200, { 'Content-Type' => 'application/json' }, [body]]
      }
    end.to_app
  end

  let(:issuer) { "#{site}/realms/#{realm}" }
  let(:endpoints) do
    {
      auth: "#{issuer}/protocol/openid-connect/auth",
      config: "#{issuer}/.well-known/openid-configuration",
      token: "#{issuer}/protocol/openid-connect/token",
      certs: "#{issuer}/protocol/openid-connect/certs",
      userinfo: "#{issuer}/protocol/openid-connect/userinfo"
    }
  end

  # Signs a JWT with the current example's RSA private key.
  def mint_token(overrides = {})
    now = Time.now.to_i
    payload = {
      iss: issuer,
      iat: now,
      exp: now + 3600,
      sub: 'user-abc123',
      name: 'Alice Example',
      email: 'alice@example.com',
      given_name: 'Alice',
      family_name: 'Example',
      preferred_username: 'alice'
    }.merge(overrides)
    JWT.encode(payload, key, 'RS256', { kid: jwk.kid })
  end

  def stub_endpoint(method, name, code, **body)
    stub_request(method, endpoints.fetch(name)).to_return(
      status: code,
      headers: { 'Content-Type' => 'application/json' },
      body: JSON.generate(body)
    )
  end

  before do
    OmniAuth.config.test_mode = false # important

    stub_endpoint :get, :config, 200,
                  issuer: issuer,
                  authorization_endpoint: endpoints[:auth],
                  token_endpoint: endpoints[:token],
                  jwks_uri: endpoints[:certs],
                  userinfo_endpoint: endpoints[:userinfo]

    stub_endpoint :get, :certs, 200, keys: [jwk.export]
  end

  after { OmniAuth.config.test_mode = false }

  describe 'callback with a valid RS256 access token' do
    let(:access_token) { mint_token }

    before do
      stub_endpoint :post, :token, 200,
                    access_token: access_token,
                    token_type: 'bearer',
                    expires_in: 3600
    end

    it 'succeeds and returns HTTP 200' do
      get '/auth/keycloak/callback', { code: 'auth-code' }
      expect(last_response.status).to eq(200)
    end

    it 'returns a usable token' do
      get '/auth/keycloak/callback', { code: 'auth-code' }

      expect(JSON.parse(last_response.body)).to include(
        'provider' => 'keycloak',
        'uid' => 'user-abc123',
        'info' => {
          'name' => 'Alice Example',
          'email' => 'alice@example.com',
          'first_name' => 'Alice',
          'last_name' => 'Example'
        },
        'extra' => {
          'raw_info' => include(
            'sub' => 'user-abc123',
            'iss' => issuer
          )
        }
      )
    end
  end

  describe 'callback with access_token and id_token' do
    let(:access_token) { mint_token }
    let(:id_token)     { mint_token(sub: 'user-abc123', azp: 'test-client') }

    before do
      stub_endpoint :post, :token, 200,
                    access_token: access_token,
                    id_token: id_token,
                    token_type: 'bearer',
                    expires_in: 3600
    end

    it 'exposes the raw id_token in extra' do
      get '/auth/keycloak/callback', { code: 'auth-code' }

      expect(JSON.parse(last_response.body)).to include(
        'extra' => include(
          'id_token' => id_token,
          'id_info' => include(
            'sub' => 'user-abc123',
            'iss' => issuer
          )
        )
      )
    end
  end

  shared_examples 'redirects to failure endpoint' do
    it 'returns a redirect response' do
      get '/auth/keycloak/callback', { code: 'auth-code' }
      expect(last_response).to be_redirect
    end

    it 'redirects to /auth/failure' do
      get '/auth/keycloak/callback', { code: 'auth-code' }
      expect(last_response.location).to include('/auth/failure')
    end
  end

  describe 'callback with an expired access token' do
    before do
      stub_endpoint :post, :token, 200,
                    access_token: mint_token(exp: Time.now.to_i - 30),
                    token_type: 'bearer',
                    expires_in: 0
    end

    it_behaves_like 'redirects to failure endpoint'
  end

  describe 'callback with a token that has a wrong issuer' do
    before do
      stub_endpoint :post, :token, 200,
                    access_token: mint_token(iss: 'https://evil.example.com/realms/evil'),
                    token_type: 'bearer',
                    expires_in: 3600
    end

    it_behaves_like 'redirects to failure endpoint'
  end

  describe 'callback with a token signed by the wrong key' do
    let(:attacker_key) { OpenSSL::PKey::RSA.new File.read(File.join(__dir__, '../../attacker.key')) }

    before do
      # Token is signed by a different key but carries the legitimate kid,
      # so the strategy will locate the correct public key and signature
      # verification will fail.
      now = Time.now.to_i
      forged_token = JWT.encode(
        { iss: issuer, iat: now, exp: now + 3600, sub: 'attacker' },
        attacker_key,
        'RS256',
        { kid: jwk.kid }
      )

      stub_endpoint :post, :token, 200,
                    access_token: forged_token,
                    token_type: 'bearer',
                    expires_in: 3600
    end

    it_behaves_like 'redirects to failure endpoint'
  end

  describe 'when the OIDC configuration endpoint is unavailable' do
    let(:app) do
      client_options = { site: site, realm: realm, raise_on_failure: true }

      Rack::Builder.new do
        use Rack::Session::Pool, expire_after: 60
        use OmniAuth::Builder do
          provider :keycloak, 'test-client', 'test-secret',
                   provider_ignores_state: true,
                   client_options: client_options
        end

        run ->(_env) { [200, { 'Content-Type' => 'application/json' }, ['OK']] }
      end.to_app
    end

    before { stub_request(:get, endpoints[:config]).to_return(status: 503, body: '', headers: {}) }

    it_behaves_like 'redirects to failure endpoint'
  end

  describe 'when the JWKS endpoint is unavailable' do
    let(:app) do
      client_options = { site: site, realm: realm, raise_on_failure: true }

      Rack::Builder.new do
        use Rack::Session::Pool, expire_after: 60
        use OmniAuth::Builder do
          provider :keycloak, 'test-client', 'test-secret',
                   provider_ignores_state: true,
                   client_options: client_options
        end

        run ->(_env) { [200, { 'Content-Type' => 'application/json' }, ['OK']] }
      end.to_app
    end

    before { stub_request(:get, endpoints[:certs]).to_return(status: 503, body: '', headers: {}) }

    it_behaves_like 'redirects to failure endpoint'
  end
end

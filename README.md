# Omniauth::Keycloak

[![Gem Version](https://badge.fury.io/rb/omniauth-keycloak.svg)](https://badge.fury.io/rb/omniauth-keycloak)
[![Ruby specs](https://github.com/ccrockett/omniauth-keycloak/actions/workflows/ci.yml/badge.svg)](https://github.com/ccrockett/omniauth-keycloak/actions/workflows/ci.yml)
[![RuboCop](https://github.com/ccrockett/omniauth-keycloak/actions/workflows/rubocop.yml/badge.svg)](https://github.com/ccrockett/omniauth-keycloak/actions/workflows/rubocop.yml)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'omniauth-keycloak'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install omniauth-keycloak

## Usage

`OmniAuth::Strategies::Keycloak` is simply a Rack middleware. Read the OmniAuth docs for detailed instructions: https://github.com/intridea/omniauth.

Here's a quick example, adding the middleware to a Rails app in `config/initializers/omniauth.rb`:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  provider :keycloak,
    'client-id',
    'client-secret',
    client_options: { site: 'https://keycloak.example.org', realm: 'example-realm' }
end
```
This will allow a POST request to `auth/keycloak` since the name is set to keycloak

Or using a proc setup with a custom options:

```ruby
Rails.application.config.middleware.use OmniAuth::Builder do
  SETUP_PROC = lambda do |env|
    request = Rack::Request.new(env)
    organization = Organization.find_by(host: request.host)
    provider_config = organization.enabled_omniauth_providers[:keycloak]

    env['omniauth.strategy'].options[:client_id] = provider_config[:client_id]
    env['omniauth.strategy'].options[:client_secret] = provider_config[:client_secret]
    env['omniauth.strategy'].options[:client_options] = { site: provider_config[:site], realm: provider_config[:realm] }
  end

  Rails.application.config.middleware.use OmniAuth::Builder do
    provider :keycloak, setup: SETUP_PROC
  end
end
```


## Devise Usage
Adapted from [Devise OmniAuth Instructions](https://github.com/plataformatec/devise/wiki/OmniAuth:-Overview)

```ruby
# app/models/user.rb
class User < ApplicationRecord
  #...
  devise :omniauthable, omniauth_providers: %i[keycloak]
  #...
end

# config/initializers/devise.rb
config.omniauth :keycloak,
                'client-id',
                'client-secret',
                client_options: { site: 'https://keycloak.example.org', realm: 'example-realm' }

# Below controller assumes callback route configuration following
# in config/routes.rb
Devise.setup do |config|
  # ...
  devise_for :users, controllers: { omniauth_callbacks: 'users/omniauth_callbacks' }
end

# app/controllers/users/omniauth_callbacks_controller.rb
class Users::OmniauthCallbacksController < Devise::OmniauthCallbacksController
  def keycloak
    Rails.logger.debug(request.env['omniauth.auth'])
    @user = User.from_omniauth(request.env['omniauth.auth'])
    if @user.persisted?
      sign_in_and_redirect @user, event: :authentication
    else
      session['devise.keycloak_data'] = request.env['omniauth.auth']
      redirect_to new_user_registration_url
    end
  end

  def failure
    redirect_to root_path
  end
end
```

## Configuration
  * __Base Url other than /auth__
  This gem tries to get the keycloak configuration from `"#{site}/realms/#{realm}/.well-known/openid-configuration"`. If your keycloak server has been setup to use a different "root" url then you need to pass in the `base_url` option when setting up the gem:
    ```ruby
    Rails.application.config.middleware.use OmniAuth::Builder do
      provider :keycloak,
        'client-id',
        'client-secret',
        client_options: { site: 'https://keycloak.example.org', realm: 'example-realm' }
    end
    ```
  * __Pass params from request thru to Keycloak__
  See [PR #24](https://github.com/ccrockett/omniauth-keycloak/pull/24) for details on how to configure this.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ccrockett/omniauth-keycloak. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Omniauth::Keycloak project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/ccrockett/omniauth-keycloak/blob/master/CODE_OF_CONDUCT.md).

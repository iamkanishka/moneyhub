defmodule MoneyHub.ConfigTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Config

  describe "new/1" do
    test "builds a valid production config with private_key_jwt" do
      assert {:ok, %Config{} = config} =
               Config.new(
                 client_id: "client-123",
                 jwk: %{"kty" => "RSA"},
                 jwk_kid: "key-1"
               )

      assert config.environment == :production
      assert config.identity_url == "https://identity.moneyhub.co.uk"
      assert config.api_url == "https://api.moneyhub.co.uk/v3.0"
      assert config.token_endpoint_auth_method == :private_key_jwt
      assert config.finch_pool == MoneyHub.Finch
    end

    test "builds a valid sandbox config with client_secret_basic" do
      assert {:ok, %Config{} = config} =
               Config.new(
                 environment: :sandbox,
                 client_id: "client-123",
                 client_secret: "shh",
                 token_endpoint_auth_method: :client_secret_basic
               )

      assert config.environment == :sandbox
      assert config.client_secret == "shh"
    end

    test "allows overriding identity_url, api_url, redirect_uri, http_options, finch_pool" do
      assert {:ok, %Config{} = config} =
               Config.new(
                 client_id: "client-123",
                 jwk: %{"kty" => "RSA"},
                 jwk_kid: "key-1",
                 identity_url: "https://custom-identity.example.com",
                 api_url: "https://custom-api.example.com/v3.0",
                 redirect_uri: "https://myapp.example.com/callback",
                 http_options: [connect_options: [timeout: 1_000]],
                 finch_pool: MyApp.CustomFinch
               )

      assert config.identity_url == "https://custom-identity.example.com"
      assert config.api_url == "https://custom-api.example.com/v3.0"
      assert config.redirect_uri == "https://myapp.example.com/callback"
      assert config.http_options == [connect_options: [timeout: 1_000]]
      assert config.finch_pool == MyApp.CustomFinch
    end

    test "errors when client_id is missing" do
      assert {:error, error} = Config.new(jwk: %{}, jwk_kid: "k")
      assert error.reason == :config_error
      assert error.message =~ "client_id"
    end

    test "errors when client_id is an empty string" do
      assert {:error, error} = Config.new(client_id: "", jwk: %{}, jwk_kid: "k")
      assert error.reason == :config_error
    end

    test "errors on invalid environment" do
      assert {:error, error} =
               Config.new(client_id: "c", jwk: %{}, jwk_kid: "k", environment: :staging)

      assert error.reason == :config_error
      assert error.message =~ "environment"
    end

    test "errors on invalid token_endpoint_auth_method" do
      assert {:error, error} =
               Config.new(client_id: "c", token_endpoint_auth_method: :client_secret_post)

      assert error.reason == :config_error
      assert error.message =~ "token_endpoint_auth_method"
    end

    test "errors when private_key_jwt is selected but jwk is missing" do
      assert {:error, error} = Config.new(client_id: "c", jwk_kid: "k")
      assert error.reason == :config_error
      assert error.message =~ "jwk"
    end

    test "errors when private_key_jwt is selected but jwk_kid is missing" do
      assert {:error, error} = Config.new(client_id: "c", jwk: %{})
      assert error.reason == :config_error
      assert error.message =~ "jwk_kid"
    end

    test "errors when client_secret_basic is selected but client_secret is missing" do
      assert {:error, error} =
               Config.new(client_id: "c", token_endpoint_auth_method: :client_secret_basic)

      assert error.reason == :config_error
      assert error.message =~ "client_secret"
    end
  end

  describe "new!/1" do
    test "returns the config directly on success" do
      assert %Config{} = Config.new!(client_id: "c", jwk: %{}, jwk_kid: "k")
    end

    test "raises ArgumentError on failure" do
      assert_raise ArgumentError, ~r/client_id/, fn -> Config.new!([]) end
    end
  end
end

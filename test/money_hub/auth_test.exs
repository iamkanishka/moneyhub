defmodule MoneyHub.AuthTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Auth
  alias MoneyHub.Auth.PrivateKeyJWT
  alias MoneyHub.Claims
  alias MoneyHub.Config
  alias MoneyHub.Scopes
  alias MoneyHub.Test.StubAdapter

  @rsa_pem_path Path.expand("../fixtures/rsa_key.pem", __DIR__)

  setup do
    jwk = PrivateKeyJWT.load_jwk!(@rsa_pem_path)

    config =
      Config.new!(
        client_id: "client-abc",
        jwk: jwk,
        jwk_kid: "kid-1",
        identity_url: "https://identity.example.com",
        redirect_uri: "https://myapp.example.com/callback",
        http_options: [adapter: &StubAdapter.call/1]
      )

    basic_config =
      Config.new!(
        client_id: "client-abc",
        client_secret: "secret-xyz",
        token_endpoint_auth_method: :client_secret_basic,
        identity_url: "https://identity.example.com",
        redirect_uri: "https://myapp.example.com/callback",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config, basic_config: basic_config}
  end

  describe "authorisation_url/2" do
    test "builds an inline URL with scope, state, claims", %{config: config} do
      claims = Claims.new() |> Claims.put_sub("user-1")

      url =
        Auth.authorisation_url(config, scope: Scopes.ais(), claims: claims, state: "fixed-state")

      uri = URI.parse(url)
      assert uri.host == "identity.example.com"
      assert uri.path == "/oidc/auth"

      query = URI.decode_query(uri.query)
      assert query["client_id"] == "client-abc"
      assert query["scope"] == "openid accounts:read transactions:read"
      assert query["state"] == "fixed-state"
      assert query["redirect_uri"] == "https://myapp.example.com/callback"
      assert Jason.decode!(query["claims"]) == claims
    end

    test "generates a random state when not provided", %{config: config} do
      url1 = Auth.authorisation_url(config, scope: "openid")
      url2 = Auth.authorisation_url(config, scope: "openid")

      state1 =
        url1 |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("state")

      state2 =
        url2 |> URI.parse() |> Map.fetch!(:query) |> URI.decode_query() |> Map.fetch!("state")

      assert state1 != state2
    end

    test "builds a PAR-backed URL from a request_uri", %{config: config} do
      url =
        Auth.authorisation_url(config, request_uri: "urn:ietf:params:oauth:request_uri:abc123")

      uri = URI.parse(url)
      query = URI.decode_query(uri.query)

      assert query["client_id"] == "client-abc"
      assert query["request_uri"] == "urn:ietf:params:oauth:request_uri:abc123"
      refute Map.has_key?(query, "scope")
    end
  end

  describe "pushed_authorisation_request/2" do
    test "signs a client assertion and posts form-encoded params (private_key_jwt)", %{
      config: config
    } do
      StubAdapter.expect(fn request ->
        assert request.method == :post
        assert to_string(request.url) == "https://identity.example.com/oidc/request"

        body = decode_form_body(request)
        assert body["client_id"] == "client-abc"
        assert body["scope"] == "openid accounts:read transactions:read"
        assert body["client_assertion_type"] =~ "jwt-bearer"
        assert is_binary(body["client_assertion"])

        {request,
         %Req.Response{
           status: 201,
           body: %{"request_uri" => "urn:ietf:params:oauth:request_uri:xyz", "expires_in" => 90}
         }}
      end)

      assert {:ok, result} = Auth.pushed_authorisation_request(config, scope: Scopes.ais())

      assert result.request_uri == "urn:ietf:params:oauth:request_uri:xyz"
      assert result.expires_in == 90
      assert result.url =~ "request_uri=urn%3Aietf%3Aparams%3Aoauth%3Arequest_uri%3Axyz"
    end

    test "uses HTTP Basic auth instead of a signed assertion (client_secret_basic)", %{
      basic_config: config
    } do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        refute Map.has_key?(body, "client_assertion")

        auth_header =
          Enum.find_value(request.headers, fn {k, v} ->
            if String.downcase(to_string(k)) == "authorization", do: v
          end)

        assert to_string(auth_header) =~ "Basic "

        {request,
         %Req.Response{status: 201, body: %{"request_uri" => "urn:abc", "expires_in" => 60}}}
      end)

      assert {:ok, _result} = Auth.pushed_authorisation_request(config, scope: "openid")
    end

    test "surfaces an API error from a failed PAR call", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 400, body: %{"error" => "invalid_request"}}}
      end)

      assert {:error, error} = Auth.pushed_authorisation_request(config, scope: "openid")
      assert error.reason == :api_error
      assert error.status == 400
    end
  end

  describe "exchange_code/3" do
    test "posts authorization_code grant and parses the token response", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["grant_type"] == "authorization_code"
        assert body["code"] == "auth-code-123"
        assert body["redirect_uri"] == "https://myapp.example.com/callback"

        {request,
         %Req.Response{
           status: 200,
           body: %{
             "access_token" => "at-1",
             "id_token" => "idt-1",
             "refresh_token" => "rt-1",
             "token_type" => "Bearer",
             "expires_in" => 3600,
             "scope" => "openid accounts:read"
           }
         }}
      end)

      assert {:ok, tokens} = Auth.exchange_code(config, "auth-code-123")
      assert tokens.access_token == "at-1"
      assert tokens.id_token == "idt-1"
      assert tokens.refresh_token == "rt-1"
      assert tokens.token_type == "Bearer"
      assert tokens.expires_in == 3600
      assert tokens.scope == "openid accounts:read"
    end

    test "allows overriding redirect_uri per call", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["redirect_uri"] == "https://other.example.com/cb"
        {request, %Req.Response{status: 200, body: %{"access_token" => "at"}}}
      end)

      assert {:ok, _} =
               Auth.exchange_code(config, "code", redirect_uri: "https://other.example.com/cb")
    end

    test "surfaces an api_error on failure", %{config: config} do
      StubAdapter.expect(fn request ->
        {request, %Req.Response{status: 400, body: %{"error" => "invalid_grant"}}}
      end)

      assert {:error, error} = Auth.exchange_code(config, "bad-code")
      assert error.reason == :api_error
      assert error.code == "invalid_grant"
    end
  end

  describe "token_for_user/3" do
    test "requests an unscoped client_credentials token with no user_id", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["grant_type"] == "client_credentials"
        refute Map.has_key?(body, "claims")
        {request, %Req.Response{status: 200, body: %{"access_token" => "at-app"}}}
      end)

      assert {:ok, tokens} = Auth.token_for_user(config)
      assert tokens.access_token == "at-app"
    end

    test "scopes the token to a user via the sub claim", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["grant_type"] == "client_credentials"
        claims = Jason.decode!(body["claims"])
        assert claims["id_token"]["sub"]["value"] == "user-42"
        {request, %Req.Response{status: 200, body: %{"access_token" => "at-user-42"}}}
      end)

      assert {:ok, tokens} = Auth.token_for_user(config, "user-42")
      assert tokens.access_token == "at-user-42"
    end

    test "includes an explicit :scope option when given", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["scope"] == "accounts:read"
        {request, %Req.Response{status: 200, body: %{"access_token" => "at"}}}
      end)

      assert {:ok, _} = Auth.token_for_user(config, "user-1", scope: "accounts:read")
    end
  end

  describe "refresh_token/2" do
    test "posts a refresh_token grant", %{config: config} do
      StubAdapter.expect(fn request ->
        body = decode_form_body(request)
        assert body["grant_type"] == "refresh_token"
        assert body["refresh_token"] == "rt-old"

        {request,
         %Req.Response{
           status: 200,
           body: %{"access_token" => "at-new", "refresh_token" => "rt-new"}
         }}
      end)

      assert {:ok, tokens} = Auth.refresh_token(config, "rt-old")
      assert tokens.access_token == "at-new"
      assert tokens.refresh_token == "rt-new"
    end
  end

  defp decode_form_body(request) do
    case request.body do
      body when is_binary(body) -> URI.decode_query(body)
      other -> other
    end
  end
end

defmodule MoneyHub.Config do
  @moduledoc """
  Configuration for a `MoneyHub` API client.

  A `MoneyHub.Config` struct carries everything needed to talk to the
  Moneyhub Open Finance API: which environment to use, the OAuth2 client
  identity, and the key material used to authenticate that client.

  ## Environments

  Moneyhub exposes (at least) two environments:

    * `:production` - `https://identity.moneyhub.co.uk` /
      `https://api.moneyhub.co.uk`
    * `:sandbox` - Moneyhub's test environment, used with mock banks during
      development. Moneyhub provisions the exact host for this per-client;
      pass `:identity_url` / `:api_url` explicitly if your sandbox host
      differs from the default.

  ## Client authentication

  Moneyhub's token endpoint supports two client authentication methods:

    * `private_key_jwt` (recommended, required in production) - the client
      signs a JWT assertion with its own private key. Configure this with
      `:jwk` (a JOSE JWK map/struct) and `:jwk_kid`.
    * `client_secret_basic` (sandbox/early development only) - HTTP Basic
      auth with `:client_id` / `:client_secret`.

  ## Example

      config = MoneyHub.Config.new!(
        environment: :sandbox,
        client_id: "abc123",
        jwk: MoneyHub.Auth.PrivateKeyJWT.load_jwk!("priv/keys/sandbox.pem"),
        jwk_kid: "sandbox-signing-key-1"
      )

  """

  alias MoneyHub.Error

  @type environment :: :production | :sandbox

  @type t :: %__MODULE__{
          environment: environment(),
          identity_url: String.t(),
          api_url: String.t(),
          client_id: String.t(),
          client_secret: String.t() | nil,
          jwk: map() | nil,
          jwk_kid: String.t() | nil,
          redirect_uri: String.t() | nil,
          token_endpoint_auth_method: :private_key_jwt | :client_secret_basic,
          http_options: keyword(),
          finch_pool: atom()
        }

  @enforce_keys [:client_id]
  defstruct environment: :production,
            identity_url: nil,
            api_url: nil,
            client_id: nil,
            client_secret: nil,
            jwk: nil,
            jwk_kid: nil,
            redirect_uri: nil,
            token_endpoint_auth_method: :private_key_jwt,
            http_options: [],
            finch_pool: MoneyHub.Finch

  @default_urls %{
    production: %{
      identity_url: "https://identity.moneyhub.co.uk",
      api_url: "https://api.moneyhub.co.uk/v3.0"
    },
    sandbox: %{
      identity_url: "https://identity.moneyhub.co.uk",
      api_url: "https://api.moneyhub.co.uk/v3.0"
    }
  }

  @doc """
  Builds a new `t:t/0`, raising `ArgumentError` on invalid options.

  ## Options

    * `:environment` - `:production` or `:sandbox`. Defaults to `:production`.
    * `:client_id` - required. The OAuth2 `client_id` issued by Moneyhub.
    * `:client_secret` - required only when
      `:token_endpoint_auth_method` is `:client_secret_basic`.
    * `:jwk` - required when `:token_endpoint_auth_method` is
      `:private_key_jwt` (the default). A JOSE JWK as a map or
      `JOSE.JWK` struct - see `MoneyHub.Auth.PrivateKeyJWT`.
    * `:jwk_kid` - the `kid` to embed in signed JWT headers. Required
      alongside `:jwk`.
    * `:redirect_uri` - the redirect URI registered for this client. Required
      to build authorisation URLs via `MoneyHub.Auth`.
    * `:token_endpoint_auth_method` - `:private_key_jwt` (default) or
      `:client_secret_basic`.
    * `:identity_url` - override the OIDC issuer base URL.
    * `:api_url` - override the data API base URL.
    * `:http_options` - extra options merged into every `Req` request (for
      example `[connect_options: [timeout: 5_000]]`).
    * `:finch_pool` - the named Finch pool to use. Defaults to
      MoneyHub.Finch, started automatically by the MoneyHub.Application
      supervisor.
  """
  @spec new!(keyword()) :: t()
  def new!(opts) when is_list(opts) do
    case new(opts) do
      {:ok, config} -> config
      {:error, %Error{} = error} -> raise ArgumentError, Error.message(error)
    end
  end

  @doc """
  Builds a new `t:t/0`, returning `{:ok, config}` or `{:error, reason}`.
  """
  @spec new(keyword()) :: {:ok, t()} | {:error, Error.t()}
  def new(opts) when is_list(opts) do
    with {:ok, client_id} <- fetch_required(opts, :client_id),
         environment = Keyword.get(opts, :environment, :production),
         {:ok, environment} <- validate_environment(environment),
         auth_method = Keyword.get(opts, :token_endpoint_auth_method, :private_key_jwt),
         {:ok, auth_method} <- validate_auth_method(auth_method),
         :ok <- validate_auth_material(auth_method, opts) do
      defaults = Map.fetch!(@default_urls, environment)

      config = %__MODULE__{
        environment: environment,
        identity_url: Keyword.get(opts, :identity_url, defaults.identity_url),
        api_url: Keyword.get(opts, :api_url, defaults.api_url),
        client_id: client_id,
        client_secret: Keyword.get(opts, :client_secret),
        jwk: Keyword.get(opts, :jwk),
        jwk_kid: Keyword.get(opts, :jwk_kid),
        redirect_uri: Keyword.get(opts, :redirect_uri),
        token_endpoint_auth_method: auth_method,
        http_options: Keyword.get(opts, :http_options, []),
        finch_pool: Keyword.get(opts, :finch_pool, MoneyHub.Finch)
      }

      {:ok, config}
    end
  end

  defp fetch_required(opts, key) do
    case Keyword.fetch(opts, key) do
      {:ok, value} when is_binary(value) and value != "" ->
        {:ok, value}

      _ ->
        {:error, Error.config_error("missing required config option #{inspect(key)}")}
    end
  end

  defp validate_environment(env) when env in [:production, :sandbox], do: {:ok, env}

  defp validate_environment(other) do
    {:error,
     Error.config_error(
       "invalid :environment #{inspect(other)}, expected :production or :sandbox"
     )}
  end

  defp validate_auth_method(method) when method in [:private_key_jwt, :client_secret_basic] do
    {:ok, method}
  end

  defp validate_auth_method(other) do
    {:error,
     Error.config_error(
       "invalid :token_endpoint_auth_method #{inspect(other)}, " <>
         "expected :private_key_jwt or :client_secret_basic"
     )}
  end

  defp validate_auth_material(:private_key_jwt, opts) do
    jwk = Keyword.get(opts, :jwk)
    kid = Keyword.get(opts, :jwk_kid)

    cond do
      is_nil(jwk) ->
        {:error, Error.config_error("token_endpoint_auth_method :private_key_jwt requires :jwk")}

      is_nil(kid) or kid == "" ->
        {:error,
         Error.config_error("token_endpoint_auth_method :private_key_jwt requires :jwk_kid")}

      true ->
        :ok
    end
  end

  defp validate_auth_material(:client_secret_basic, opts) do
    case Keyword.get(opts, :client_secret) do
      secret when is_binary(secret) and secret != "" ->
        :ok

      _ ->
        {:error,
         Error.config_error(
           "token_endpoint_auth_method :client_secret_basic requires :client_secret"
         )}
    end
  end
end

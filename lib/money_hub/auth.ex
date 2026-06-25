defmodule MoneyHub.Auth do
  @moduledoc """
  OIDC authentication flows: Pushed Authorisation Requests, authorisation
  URLs, code exchange, and client-credentials tokens.

  Moneyhub's auth flow has three shapes depending on what you're doing:

  1. **Bank connection (AIS)** - drive the user through `/oidc/auth` (or a
     PAR-backed `request_uri`) to connect a bank account, then exchange the
     returned `code` for tokens.
  2. **Payments (PIS)** - same shape, but the `claims` parameter carries a
     `mh:payment` / `mh:recurring_payment` / `mh:standing_order` claim
     instead of (or alongside) AIS scopes.
  3. **Ongoing data access** - once a user is registered (their `sub` is
     known from step 1's `id_token`), fetch a `client_credentials` token
     scoped to that user via `token_for_user/2` and call the data API
     directly - no further browser redirect needed.

  ## Example: connect a bank account (ongoing access, new user)

      claims = MoneyHub.Claims.new() |> MoneyHub.Claims.put_sub()

      {:ok, %{url: url, request_uri: request_uri}} =
        MoneyHub.Auth.pushed_authorisation_request(config,
          scope: MoneyHub.Scopes.ais_offline(),
          claims: claims
        )

      # redirect the user's browser to `url`, they authenticate at their
      # bank, and your redirect_uri receives `?code=...`

      {:ok, tokens} = MoneyHub.Auth.exchange_code(config, code)
      {:ok, claims} = MoneyHub.Auth.IdToken.verify(tokens.id_token, config)
      user_id = claims["sub"]

  ## Example: get a data token for an already-connected user

      {:ok, token} = MoneyHub.Auth.token_for_user(config, user_id)
      {:ok, accounts} = MoneyHub.Accounts.list(config, token.access_token)

  """

  alias MoneyHub.Auth.PrivateKeyJWT
  alias MoneyHub.Claims
  alias MoneyHub.Error

  @type tokens :: %{
          access_token: String.t(),
          id_token: String.t() | nil,
          refresh_token: String.t() | nil,
          token_type: String.t(),
          expires_in: integer() | nil,
          scope: String.t() | nil
        }

  @doc """
  Sends a Pushed Authorisation Request (PAR) to `/oidc/request` and
  returns the `request_uri` to embed in the authorisation URL, alongside
  the ready-to-use full URL.

  PAR keeps sensitive parameters (notably `claims`, which can be large and
  contain payment payloads) off of the browser's URL bar entirely: only an
  opaque `request_uri` reference is exposed client-side.

  ## Options

    * `:scope` - required. A space-delimited scope string, e.g. from
      `MoneyHub.Scopes`.
    * `:claims` - a `MoneyHub.Claims` map, or any term accepted by
      `Jason.encode!/1`, to be embedded as the `claims` parameter.
    * `:state` - an opaque value round-tripped back on redirect. Generated
      randomly if omitted.
    * `:redirect_uri` - overrides `config.redirect_uri` for this request.
    * `:response_type` - defaults to `"code"`.
  """
  @spec pushed_authorisation_request(MoneyHub.Config.t(), keyword()) ::
          {:ok, %{request_uri: String.t(), expires_in: integer(), url: String.t()}}
          | {:error, Error.t()}
  def pushed_authorisation_request(%MoneyHub.Config{} = config, opts) do
    with {:ok, params} <- build_auth_params(config, opts),
         {:ok, body} <- par_body(config, params),
         {:ok, response} <- post_form(config, "/oidc/request", body) do
      case response do
        %Req.Response{status: status, body: %{"request_uri" => request_uri} = resp_body}
        when status in 200..201 ->
          url = authorisation_url(config, request_uri: request_uri)
          {:ok, %{request_uri: request_uri, expires_in: resp_body["expires_in"], url: url}}

        %Req.Response{status: status, body: resp_body} ->
          {:error, Error.api_error(status, resp_body)}
      end
    end
  end

  @doc """
  Builds an `/oidc/auth` authorisation URL.

  Pass either the same options as `pushed_authorisation_request/2`
  (`:scope`, `:claims`, `:state`, ...) to build a URL with parameters
  inline, or `request_uri:` (as returned by
  `pushed_authorisation_request/2`) to build a PAR-backed URL.
  """
  @spec authorisation_url(MoneyHub.Config.t(), keyword()) :: String.t()
  def authorisation_url(%MoneyHub.Config{} = config, request_uri: request_uri) do
    query =
      URI.encode_query(%{
        "client_id" => config.client_id,
        "request_uri" => request_uri
      })

    config.identity_url <> "/oidc/auth?" <> query
  end

  def authorisation_url(%MoneyHub.Config{} = config, opts) do
    {:ok, params} = build_auth_params(config, opts)
    config.identity_url <> "/oidc/auth?" <> URI.encode_query(params)
  end

  @doc """
  Exchanges an authorisation `code` (returned to your `redirect_uri`) for
  tokens at `/oidc/token`, using `authorization_code` grant.
  """
  @spec exchange_code(MoneyHub.Config.t(), String.t(), keyword()) ::
          {:ok, tokens()} | {:error, Error.t()}
  def exchange_code(%MoneyHub.Config{} = config, code, opts \\ []) when is_binary(code) do
    redirect_uri = Keyword.get(opts, :redirect_uri, config.redirect_uri)

    base = %{
      "grant_type" => "authorization_code",
      "code" => code,
      "redirect_uri" => redirect_uri
    }

    request_token(config, base)
  end

  @doc """
  Fetches a `client_credentials` token, optionally scoped to a specific
  Moneyhub user (via the `sub` claim) for ongoing data access.

  Once a user has completed an AIS connection (their `sub` known from the
  `id_token` of `exchange_code/3`), call this to obtain a fresh
  `access_token` for reading that user's data - no browser interaction
  required.
  """
  @spec token_for_user(MoneyHub.Config.t(), String.t() | nil, keyword()) ::
          {:ok, tokens()} | {:error, Error.t()}
  def token_for_user(config, user_id \\ nil, opts \\ [])

  def token_for_user(%MoneyHub.Config{} = config, nil, opts) do
    scope = Keyword.get(opts, :scope)
    base = %{"grant_type" => "client_credentials"}
    base = if scope, do: Map.put(base, "scope", scope), else: base
    request_token(config, base)
  end

  def token_for_user(%MoneyHub.Config{} = config, user_id, opts) when is_binary(user_id) do
    scope = Keyword.get(opts, :scope)

    claims =
      Claims.new()
      |> Claims.put_sub(user_id)
      |> Claims.to_json!()

    base = %{"grant_type" => "client_credentials", "claims" => claims}
    base = if scope, do: Map.put(base, "scope", scope), else: base
    request_token(config, base)
  end

  @doc """
  Exchanges a `refresh_token` for a fresh token set, using `refresh_token`
  grant. Requires the original authorisation to have included
  `offline_access`.
  """
  @spec refresh_token(MoneyHub.Config.t(), String.t()) :: {:ok, tokens()} | {:error, Error.t()}
  def refresh_token(%MoneyHub.Config{} = config, refresh_token) when is_binary(refresh_token) do
    request_token(config, %{"grant_type" => "refresh_token", "refresh_token" => refresh_token})
  end

  # -- internals --------------------------------------------------------

  defp build_auth_params(config, opts) do
    scope = Keyword.fetch!(opts, :scope)
    claims = Keyword.get(opts, :claims)
    state = Keyword.get(opts, :state, generate_state())
    redirect_uri = Keyword.get(opts, :redirect_uri, config.redirect_uri)
    response_type = Keyword.get(opts, :response_type, "code")

    params = %{
      "client_id" => config.client_id,
      "response_type" => response_type,
      "redirect_uri" => redirect_uri,
      "scope" => scope,
      "state" => state
    }

    params =
      case claims do
        nil ->
          {:ok, params}

        %{} = claims ->
          with {:ok, json} <- Claims.to_json(claims), do: {:ok, Map.put(params, "claims", json)}

        other ->
          {:ok, Map.put(params, "claims", Jason.encode!(other))}
      end

    case params do
      {:ok, p} -> {:ok, p}
      {:error, _} = error -> error
    end
  end

  defp par_body(config, params) do
    case config.token_endpoint_auth_method do
      :private_key_jwt ->
        with {:ok, assertion} <- PrivateKeyJWT.sign_client_assertion(config) do
          {:ok,
           Map.merge(params, %{
             "client_id" => config.client_id,
             "client_assertion_type" => "urn:ietf:params:oauth:client-assertion-type:jwt-bearer",
             "client_assertion" => assertion
           })}
        end

      :client_secret_basic ->
        {:ok, params}
    end
  end

  defp request_token(config, base_params) do
    with {:ok, body} <- par_body(config, base_params),
         {:ok, response} <- post_form(config, "/oidc/token", body) do
      case response do
        %Req.Response{status: 200, body: resp_body} ->
          {:ok, parse_tokens(resp_body)}

        %Req.Response{status: status, body: resp_body} ->
          {:error, Error.api_error(status, resp_body)}
      end
    end
  end

  defp parse_tokens(body) do
    %{
      access_token: body["access_token"],
      id_token: body["id_token"],
      refresh_token: body["refresh_token"],
      token_type: body["token_type"],
      expires_in: body["expires_in"],
      scope: body["scope"]
    }
  end

  defp post_form(config, path, body) do
    url = config.identity_url <> path

    auth_opts =
      case config.token_endpoint_auth_method do
        :client_secret_basic -> [auth: {:basic, "#{config.client_id}:#{config.client_secret}"}]
        :private_key_jwt -> []
      end

    req_opts =
      Keyword.merge(
        [
          url: url,
          form: body,
          finch: config.finch_pool,
          retry: false
        ] ++ auth_opts,
        config.http_options
      )

    case Req.post(req_opts) do
      {:ok, %Req.Response{}} = ok -> ok
      {:error, exception} -> {:error, Error.network_error(exception)}
    end
  end

  defp generate_state do
    16 |> :crypto.strong_rand_bytes() |> Base.url_encode64(padding: false)
  end
end

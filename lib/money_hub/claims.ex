defmodule MoneyHub.Claims do
  @moduledoc """
  Builds the OIDC `claims` request parameter Moneyhub uses to drive
  connection behaviour.

  Moneyhub layers a set of `mh:*` custom claims on top of standard OIDC
  claims. They're passed as the (URL-encoded, JSON-serialised) `claims`
  parameter on the authorisation request - either inline, wrapped in a
  signed request object (see `MoneyHub.Auth.PrivateKeyJWT`), or via Pushed
  Authorisation Requests (see `MoneyHub.Auth`).

  Every claim lives under `id_token` in the resulting JSON (Moneyhub does
  not currently read claims from `userinfo`).

  ## Example: register a new user for ongoing access

      MoneyHub.Claims.new()
      |> MoneyHub.Claims.put_sub()
      |> MoneyHub.Claims.to_json()

  ## Example: connect a specific existing user

      MoneyHub.Claims.new()
      |> MoneyHub.Claims.put_sub("5c1907c0e6b340e5c056fb2a")
      |> MoneyHub.Claims.to_json()

  ## Example: refresh an existing connection

      MoneyHub.Claims.new()
      |> MoneyHub.Claims.put_sub("5c1907c0e6b340e5c056fb2a")
      |> MoneyHub.Claims.put_connection_id("b74f1a79f0be8bdb857d82d0f041d7d2:0f1aa7c1-6379-483a-bfd8-ae0a208fb635")
      |> MoneyHub.Claims.to_json()

  ## Example: create a single immediate payment

      MoneyHub.Claims.new()
      |> MoneyHub.Claims.put_sub()
      |> MoneyHub.Claims.put_payment(%{
        "amount" => %{"amount" => 10.5, "currency" => "GBP"},
        "creditorAccount" => %{"identification" => %{"sortCode" => "010203", "accountNumber" => "12345678"}},
        "reference" => "Invoice 123"
      })
      |> MoneyHub.Claims.to_json()

  """

  alias MoneyHub.Error

  @type t :: %{optional(String.t()) => term()}

  @doc "Starts an empty claims builder."
  @spec new() :: t()
  def new, do: %{}

  @doc """
  Sets the `sub` claim, identifying which Moneyhub user this connection or
  action belongs to.

  Called with no `user_id`, this marks the claim `essential` without a
  fixed `value`, letting Moneyhub assign a new user and report their id in
  the returned `id_token` (used when registering a brand-new user). Called
  with a `user_id`, it pins the connection/action to that specific,
  already-registered user.
  """
  @spec put_sub(t(), String.t() | nil) :: t()
  def put_sub(claims, user_id \\ nil)

  def put_sub(claims, nil) do
    put_id_token_claim(claims, "sub", %{"essential" => true})
  end

  def put_sub(claims, user_id) when is_binary(user_id) do
    put_id_token_claim(claims, "sub", %{"essential" => true, "value" => user_id})
  end

  @doc """
  Sets the `mh:con_id` claim to target a specific existing connection - used
  to refresh/re-sync a connection or to request re-authentication
  (re-consent) for it.
  """
  @spec put_connection_id(t(), String.t()) :: t()
  def put_connection_id(claims, connection_id) when is_binary(connection_id) do
    put_id_token_claim(claims, "mh:con_id", %{
      "essential" => true,
      "value" => connection_id
    })
  end

  @doc """
  Sets the `mh:cat_type` claim, controlling whether returned transactions
  are categorised using the `"personal"` or `"business"` category set.
  """
  @spec put_category_type(t(), :personal | :business) :: t()
  def put_category_type(claims, type) when type in [:personal, :business] do
    put_id_token_claim(claims, "mh:cat_type", %{
      "essential" => true,
      "value" => Atom.to_string(type)
    })
  end

  @doc """
  Sets the `mh:payment` claim with the given payment request payload,
  driving a single immediate payment authorisation.

  `payment` is the raw payment request map (amount, creditor account,
  reference, and so on) as documented for the payments API.
  """
  @spec put_payment(t(), map()) :: t()
  def put_payment(claims, %{} = payment) do
    put_id_token_claim(claims, "mh:payment", %{"essential" => true, "value" => payment})
  end

  @doc """
  Sets the `mh:recurring_payment` claim, driving a Variable Recurring
  Payment (VRP) consent authorisation.
  """
  @spec put_recurring_payment(t(), map()) :: t()
  def put_recurring_payment(claims, %{} = recurring_payment) do
    put_id_token_claim(claims, "mh:recurring_payment", %{
      "essential" => true,
      "value" => recurring_payment
    })
  end

  @doc """
  Sets the `mh:standing_order` claim, driving a standing order creation
  authorisation.
  """
  @spec put_standing_order(t(), map()) :: t()
  def put_standing_order(claims, %{} = standing_order) do
    put_id_token_claim(claims, "mh:standing_order", %{
      "essential" => true,
      "value" => standing_order
    })
  end

  @doc """
  Sets an arbitrary `mh:*` (or any other) claim under `id_token` with the
  given essential flag and/or fixed value. Use this for claims not yet
  covered by a dedicated `put_*/2` function.
  """
  @spec put(t(), String.t(), keyword()) :: t()
  def put(claims, claim_name, opts \\ []) when is_binary(claim_name) and is_list(opts) do
    entry =
      %{}
      |> maybe_put("essential", Keyword.get(opts, :essential, true))
      |> maybe_put("value", Keyword.get(opts, :value))
      |> maybe_put("values", Keyword.get(opts, :values))

    put_id_token_claim(claims, claim_name, entry)
  end

  defp maybe_put(map, _key, nil), do: map
  defp maybe_put(map, key, value), do: Map.put(map, key, value)

  defp put_id_token_claim(claims, name, entry) do
    Map.update(claims, "id_token", %{name => entry}, &Map.put(&1, name, entry))
  end

  @doc """
  Serialises the claims builder to a JSON string suitable for the `claims`
  authorisation parameter.
  """
  @spec to_json(t()) :: {:ok, String.t()} | {:error, Error.t()}
  def to_json(claims) when is_map(claims) do
    {:ok, Jason.encode!(claims)}
  rescue
    e -> {:error, Error.validation_error("could not encode claims to JSON: #{inspect(e)}")}
  end

  @doc "Same as `to_json/1` but raises on failure."
  @spec to_json!(t()) :: String.t()
  def to_json!(claims) do
    case to_json(claims) do
      {:ok, json} -> json
      {:error, error} -> raise error
    end
  end
end

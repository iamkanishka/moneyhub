defmodule MoneyHub.Error do
  @moduledoc """
  A structured error returned by `MoneyHub` functions.

  Every public function in this library that can fail returns
  `{:error, %MoneyHub.Error{}}` (or raises a `MoneyHub.Error` from the `!`
  variants) rather than ad-hoc tuples, so callers can pattern match on
  `reason` regardless of where in the stack the failure occurred.

  ## Reasons

    * `:config_error` - the `MoneyHub.Config` passed in was invalid.
    * `:network_error` - the HTTP transport failed (DNS, TLS, connect
      timeout, connection reset, etc). `cause` holds the underlying
      exception or `Mint`/`Finch` error term.
    * `:api_error` - the API responded with a non-2xx status. `status` and
      `body` are populated; `code` is the Moneyhub-specific error code
      from the response body when present (e.g. `"INVALID_REQUEST"`).
    * `:rate_limited` - the API responded `429`. `retry_after` (integer
      seconds) is populated when the `Retry-After` header was present.
    * `:decode_error` - the response body could not be parsed as JSON or
      did not match the expected shape.
    * `:jwt_error` - signing or verifying a JWT (client assertion, id_token,
      webhook payload) failed. `cause` holds the underlying reason.
    * `:validation_error` - a function argument failed local validation
      before any request was made (for example an invalid claims map).

  """

  @type reason ::
          :config_error
          | :network_error
          | :api_error
          | :rate_limited
          | :decode_error
          | :jwt_error
          | :validation_error

  @type t :: %__MODULE__{
          reason: reason(),
          message: String.t(),
          status: pos_integer() | nil,
          code: String.t() | nil,
          body: term(),
          retry_after: non_neg_integer() | nil,
          cause: term()
        }

  defexception reason: :api_error,
               message: "",
               status: nil,
               code: nil,
               body: nil,
               retry_after: nil,
               cause: nil

  @impl Exception
  def message(%__MODULE__{message: message}), do: message

  @doc false
  @spec config_error(String.t()) :: t()
  def config_error(message), do: %__MODULE__{reason: :config_error, message: message}

  @doc false
  @spec validation_error(String.t()) :: t()
  def validation_error(message), do: %__MODULE__{reason: :validation_error, message: message}

  @doc false
  @spec network_error(term()) :: t()
  def network_error(cause) do
    %__MODULE__{
      reason: :network_error,
      message: "network error: #{inspect(cause)}",
      cause: cause
    }
  end

  @doc false
  @spec decode_error(String.t(), term()) :: t()
  def decode_error(message, cause \\ nil) do
    %__MODULE__{reason: :decode_error, message: message, cause: cause}
  end

  @doc false
  @spec jwt_error(String.t(), term()) :: t()
  def jwt_error(message, cause \\ nil) do
    %__MODULE__{reason: :jwt_error, message: message, cause: cause}
  end

  @doc false
  @spec api_error(pos_integer(), term(), [{String.t(), String.t()}]) :: t()
  def api_error(status, body, headers \\ []) do
    code = extract_code(body)

    %__MODULE__{
      reason: api_reason(status),
      message: api_message(status, code, body),
      status: status,
      code: code,
      body: body,
      retry_after: if(status == 429, do: extract_retry_after(headers), else: nil)
    }
  end

  defp api_reason(429), do: :rate_limited
  defp api_reason(_), do: :api_error

  defp extract_code(%{"error" => code}) when is_binary(code), do: code
  defp extract_code(%{"code" => code}) when is_binary(code), do: code
  defp extract_code(%{"error_code" => code}) when is_binary(code), do: code
  defp extract_code(_), do: nil

  defp extract_retry_after(headers) do
    case List.keyfind(headers, "retry-after", 0) do
      {_, value} ->
        case Integer.parse(value) do
          {seconds, _} -> seconds
          :error -> nil
        end

      nil ->
        nil
    end
  end

  defp api_message(status, nil, _body), do: "Moneyhub API responded with status #{status}"

  defp api_message(status, code, _body),
    do: "Moneyhub API responded with status #{status} (#{code})"
end

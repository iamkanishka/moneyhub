defmodule MoneyHub.BankIconsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.BankIcons
  alias MoneyHub.Config
  alias MoneyHub.Test.StubAdapter

  setup do
    config =
      Config.new!(
        client_id: "c",
        jwk: %{"kty" => "RSA"},
        jwk_kid: "k",
        api_url: "https://api.example.com/v3.0",
        http_options: [adapter: &StubAdapter.call/1]
      )

    {:ok, config: config}
  end

  test "get/3 fetches the icon for a bank ref using a bearer token", %{config: config} do
    StubAdapter.expect(fn request ->
      assert to_string(request.url) =~ "/bank-icons/barclays"

      auth_header =
        Enum.find_value(request.headers, fn {k, v} ->
          if String.downcase(to_string(k)) == "authorization", do: v
        end)

      assert to_string(auth_header) == "Bearer tok-123"

      {request,
       %Req.Response{
         status: 200,
         headers: %{"content-type" => ["image/png"]},
         body: <<1, 2, 3>>
       }}
    end)

    assert {:ok, %Req.Response{status: 200, body: <<1, 2, 3>>}} =
             BankIcons.get(config, "tok-123", "barclays")
  end

  test "propagates a 404 for an unknown bank ref", %{config: config} do
    StubAdapter.expect(fn request ->
      {request, %Req.Response{status: 404, body: %{"error" => "NOT_FOUND"}}}
    end)

    assert {:error, error} = BankIcons.get(config, "tok-123", "nonexistent")
    assert error.status == 404
  end
end

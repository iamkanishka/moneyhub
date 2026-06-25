defmodule MoneyHub.ScopesTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Scopes

  test "individual scope constants have the expected wire values" do
    assert Scopes.openid() == "openid"
    assert Scopes.accounts_read() == "accounts:read"
    assert Scopes.accounts_details_read() == "accounts_details:read"
    assert Scopes.transactions_read() == "transactions:read"
    assert Scopes.offline_access() == "offline_access"
    assert Scopes.payment() == "payment"
    assert Scopes.payee_create() == "payee:create"
    assert Scopes.recurring_payment() == "recurring_payment"
    assert Scopes.standing_order() == "standing_order"
    assert Scopes.id_api() == "id:api"
    assert Scopes.id_test() == "id:test"
    assert Scopes.widget_authentication() == "widget_authentication"
  end

  describe "join/1" do
    test "space-joins scopes" do
      assert Scopes.join(["openid", "accounts:read"]) == "openid accounts:read"
    end

    test "deduplicates while preserving first-seen order" do
      assert Scopes.join(["openid", "accounts:read", "openid"]) == "openid accounts:read"
    end

    test "handles an empty list" do
      assert Scopes.join([]) == ""
    end

    test "handles a single scope" do
      assert Scopes.join(["openid"]) == "openid"
    end
  end

  describe "preset scope sets" do
    test "ais/0" do
      assert Scopes.ais() == "openid accounts:read transactions:read"
    end

    test "ais_offline/0" do
      assert Scopes.ais_offline() == "openid accounts:read transactions:read offline_access"
    end

    test "payments/0" do
      assert Scopes.payments() == "openid payment payee:create"
    end
  end
end

defmodule MoneyHub.ClaimsTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Claims

  describe "put_sub/2" do
    test "with no user_id, marks sub essential with no fixed value" do
      claims = Claims.new() |> Claims.put_sub()
      assert claims == %{"id_token" => %{"sub" => %{"essential" => true}}}
    end

    test "with a user_id, pins the value" do
      claims = Claims.new() |> Claims.put_sub("user-123")

      assert claims == %{
               "id_token" => %{"sub" => %{"essential" => true, "value" => "user-123"}}
             }
    end
  end

  test "put_connection_id/2" do
    claims = Claims.new() |> Claims.put_connection_id("con-abc")

    assert claims == %{
             "id_token" => %{"mh:con_id" => %{"essential" => true, "value" => "con-abc"}}
           }
  end

  describe "put_category_type/2" do
    test "accepts :personal" do
      claims = Claims.new() |> Claims.put_category_type(:personal)

      assert claims == %{
               "id_token" => %{"mh:cat_type" => %{"essential" => true, "value" => "personal"}}
             }
    end

    test "accepts :business" do
      claims = Claims.new() |> Claims.put_category_type(:business)
      assert claims["id_token"]["mh:cat_type"]["value"] == "business"
    end
  end

  test "put_payment/2 nests the raw payment payload as the claim value" do
    payment = %{"amount" => %{"amount" => 10.5, "currency" => "GBP"}}
    claims = Claims.new() |> Claims.put_payment(payment)

    assert claims == %{
             "id_token" => %{"mh:payment" => %{"essential" => true, "value" => payment}}
           }
  end

  test "put_recurring_payment/2" do
    rp = %{"maximumIndividualAmount" => %{"amount" => 50, "currency" => "GBP"}}
    claims = Claims.new() |> Claims.put_recurring_payment(rp)
    assert claims["id_token"]["mh:recurring_payment"]["value"] == rp
  end

  test "put_standing_order/2" do
    so = %{"frequency" => "monthly"}
    claims = Claims.new() |> Claims.put_standing_order(so)
    assert claims["id_token"]["mh:standing_order"]["value"] == so
  end

  describe "put/3" do
    test "defaults essential to true with no value" do
      claims = Claims.new() |> Claims.put("mh:custom")
      assert claims == %{"id_token" => %{"mh:custom" => %{"essential" => true}}}
    end

    test "supports :essential, :value, :values options" do
      claims =
        Claims.new()
        |> Claims.put("mh:custom", essential: false, value: "x", values: ["x", "y"])

      assert claims["id_token"]["mh:custom"] == %{
               "essential" => false,
               "value" => "x",
               "values" => ["x", "y"]
             }
    end
  end

  test "chaining multiple claims merges under the same id_token map" do
    claims =
      Claims.new()
      |> Claims.put_sub("user-1")
      |> Claims.put_category_type(:business)

    assert claims == %{
             "id_token" => %{
               "sub" => %{"essential" => true, "value" => "user-1"},
               "mh:cat_type" => %{"essential" => true, "value" => "business"}
             }
           }
  end

  describe "to_json/1 and to_json!/1" do
    test "round-trips through JSON" do
      claims = Claims.new() |> Claims.put_sub("user-1")
      assert {:ok, json} = Claims.to_json(claims)
      assert Jason.decode!(json) == claims
    end

    test "to_json/1 returns an error tuple for unencodable input" do
      claims = %{"id_token" => %{"bad" => {1, 2}}}
      assert {:error, error} = Claims.to_json(claims)
      assert error.reason == :validation_error
    end
  end
end

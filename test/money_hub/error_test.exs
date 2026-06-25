defmodule MoneyHub.ErrorTest do
  use ExUnit.Case, async: true

  alias MoneyHub.Error

  describe "api_error/3" do
    test "classifies 429 as :rate_limited" do
      error = Error.api_error(429, %{"error" => "RATE_LIMITED"}, [{"retry-after", "30"}])
      assert error.reason == :rate_limited
      assert error.status == 429
      assert error.code == "RATE_LIMITED"
      assert error.retry_after == 30
    end

    test "classifies other statuses as :api_error" do
      error = Error.api_error(400, %{"error" => "INVALID_REQUEST"})
      assert error.reason == :api_error
      assert error.status == 400
      assert error.code == "INVALID_REQUEST"
      assert error.retry_after == nil
    end

    test ~S(extracts code from "code" or "error_code" body keys too) do
      assert %{code: "X"} = Error.api_error(400, %{"code" => "X"})
      assert %{code: "Y"} = Error.api_error(400, %{"error_code" => "Y"})
    end

    test "handles missing/non-string code gracefully" do
      error = Error.api_error(500, %{"unexpected" => "shape"})
      assert error.code == nil
      assert error.message == "Moneyhub API responded with status 500"
    end

    test "handles non-integer Retry-After header gracefully" do
      error = Error.api_error(429, %{}, [{"retry-after", "not-a-number"}])
      assert error.retry_after == nil
    end

    test "message includes the code when present" do
      error = Error.api_error(403, %{"error" => "FORBIDDEN"})
      assert error.message == "Moneyhub API responded with status 403 (FORBIDDEN)"
    end
  end

  describe "other constructors" do
    test "config_error/1" do
      error = Error.config_error("bad config")
      assert error.reason == :config_error
      assert error.message == "bad config"
    end

    test "validation_error/1" do
      error = Error.validation_error("bad input")
      assert error.reason == :validation_error
    end

    test "network_error/1 includes the cause" do
      error = Error.network_error(:timeout)
      assert error.reason == :network_error
      assert error.cause == :timeout
      assert error.message =~ "timeout"
    end

    test "decode_error/2" do
      error = Error.decode_error("bad json", %Jason.DecodeError{})
      assert error.reason == :decode_error
      assert %Jason.DecodeError{} = error.cause
    end

    test "jwt_error/2" do
      error = Error.jwt_error("signature invalid")
      assert error.reason == :jwt_error
      assert error.cause == nil
    end
  end

  test "implements Exception.message/1" do
    error = Error.config_error("oops")
    assert Exception.message(error) == "oops"
  end

  test "is raisable" do
    assert_raise MoneyHub.Error, "boom", fn ->
      raise Error.config_error("boom")
    end
  end
end

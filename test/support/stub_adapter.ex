defmodule MoneyHub.Test.StubAdapter do
  @moduledoc """
  A minimal `Req` `:adapter` for tests, requiring no extra dependencies
  (no Plug, no Bypass, no real sockets).

  Register expected responses (or assertions) for a test process via
  `expect/1`, then build a `MoneyHub.Config` whose `:http_options` include
  `adapter: &MoneyHub.Test.StubAdapter.call/1` so every request made with
  that config is routed here instead of over the network.

  Each call to `expect/1` queues exactly one response, consumed in FIFO
  order by the next matching request from the same test process. Queues
  are stored in the process dictionary of the *test* process and looked up
  via `Process.get/1` from the (synchronous, same-process) adapter
  callback - this is sufficient because `Req.request/1` runs synchronously
  in the calling process by default (no `Task` involved) for the plain
  `:adapter` seam.
  """

  @key :money_hub_stub_adapter_queue

  @type responder :: (Req.Request.t() -> {Req.Request.t(), Req.Response.t() | Exception.t()})

  @doc """
  Queues a responder function to be returned for the next request made
  through `call/1` in the current process.

  The responder receives the built `Req.Request.t()` (so assertions can
  inspect method/url/headers/body) and must return
  `{request, %Req.Response{}}` or `{request, exception}`.
  """
  @spec expect(responder()) :: :ok
  def expect(responder) when is_function(responder, 1) do
    queue = Process.get(@key, [])
    Process.put(@key, queue ++ [responder])
    :ok
  end

  @doc """
  Convenience wrapper around `expect/1` for the common case of returning a
  fixed JSON body and status, without needing to inspect the request.
  """
  @spec expect_json(non_neg_integer(), term()) :: :ok
  def expect_json(status, body) do
    expect(fn request -> {request, %Req.Response{status: status, body: body}} end)
  end

  @doc false
  @spec call(Req.Request.t()) :: {Req.Request.t(), Req.Response.t() | Exception.t()}
  def call(request) do
    case Process.get(@key, []) do
      [] ->
        raise "MoneyHub.Test.StubAdapter: no expectations queued for #{request.method} #{request.url}"

      [responder | rest] ->
        Process.put(@key, rest)
        responder.(request)
    end
  end

  @doc "Asserts that every queued expectation for the current process has been consumed."
  @spec verify!() :: :ok
  def verify! do
    case Process.get(@key, []) do
      [] ->
        :ok

      remaining ->
        raise "MoneyHub.Test.StubAdapter: #{length(remaining)} expectation(s) not consumed"
    end
  end
end

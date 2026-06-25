defmodule MoneyHub.MixProject do
  use Mix.Project

  @source_url "https://github.com/iamkanishka/money_hub"
  @version "1.0.0"

  def project do
    [
      app: :money_hub,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      name: "MoneyHub",
      description: description(),
      package: package(),
      source_url: @source_url,
      docs: docs(),
      dialyzer: dialyzer()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :crypto, :public_key],
      mod: {MoneyHub.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      # HTTP client. castore is intentionally NOT added as an explicit
      # dependency here: Mint/Finch only use it as an *optional* fallback
      # for loading CA certificates, and pulling it in explicitly forces
      # its `mix certdata` Mix.Task to compile - which fails on some
      # Erlang/OTP installations (notably common on Windows, and on some
      # minimal Linux/Erlang packages) that don't ship the `public_key`
      # app's `include/` headers. Without it, Mint/Finch fall back to
      # `:public_key.cacerts_get/0` (built into OTP 25+), which is both
      # more portable and sufficient for talking to Moneyhub's API.
      {:req, "~> 0.5"},

      # JOSE for JWT / JWS / JWK / JWE (private_key_jwt, id_token verification, webhook JWTs)
      {:jose, "~> 1.11"},

      # Option validation for public API functions
      {:nimble_options, "~> 1.1"},

      # Telemetry events for instrumentation
      {:telemetry, "~> 1.2"},
      # Dev / test
      {:ex_doc, "~> 0.34", only: :dev, runtime: false},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false},
      {:excoveralls, "~> 0.18", only: :test},
      {:bypass, "~> 2.1", only: :test},
      {:mox, "~> 1.1", only: :test}
    ]
  end

  defp description do
    "A production-grade Elixir client for the Moneyhub Open Finance API: OIDC " <>
      "authentication (PAR, private_key_jwt, request objects), account " <>
      "aggregation (AIS), payments (SIP, VRP, standing orders, pay links), " <>
      "categorisation, affordability, and webhook verification."
  end

  defp package do
    [
      name: "money_hub",
      licenses: ["MIT"],
      links: %{"GitHub" => @source_url},
      files: ~w(lib .formatter.exs mix.exs README.md LICENSE CHANGELOG.md)
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      groups_for_modules: [
        Authentication: [
          MoneyHub.Auth,
          MoneyHub.Auth.PrivateKeyJWT,
          MoneyHub.Auth.IdToken,
          MoneyHub.Auth.JWKS,
          MoneyHub.Claims,
          MoneyHub.Scopes
        ],
        "Data Aggregation (AIS)": [
          MoneyHub.Users,
          MoneyHub.ScimUsers,
          MoneyHub.Accounts,
          MoneyHub.Transactions,
          MoneyHub.Categories,
          MoneyHub.Counterparties,
          MoneyHub.GlobalCounterparties,
          MoneyHub.Beneficiaries,
          MoneyHub.Holdings,
          MoneyHub.RegularTransactions,
          MoneyHub.RentalRecords,
          MoneyHub.SavingsGoals,
          MoneyHub.SpendingGoals,
          MoneyHub.SpendingAnalysis,
          MoneyHub.Affordability,
          MoneyHub.StandardFinancialStatements,
          MoneyHub.NotificationThresholds,
          MoneyHub.Statements,
          MoneyHub.Tax,
          MoneyHub.Projects,
          MoneyHub.AuthRequests,
          MoneyHub.Connections,
          MoneyHub.ConsentHistory,
          MoneyHub.Discovery,
          MoneyHub.BankIcons,
          MoneyHub.ResellerCheck
        ],
        Payments: [
          MoneyHub.Payees,
          MoneyHub.Payments,
          MoneyHub.RecurringPayments,
          MoneyHub.StandingOrders,
          MoneyHub.PayLinks,
          MoneyHub.PayFile
        ],
        Webhooks: [
          MoneyHub.Webhooks,
          MoneyHub.Webhooks.Event
        ],
        Internals: [
          MoneyHub.Client,
          MoneyHub.Config,
          MoneyHub.Error
        ]
      ]
    ]
  end

  defp dialyzer do
    [
      plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
      plt_add_apps: [:ex_unit, :mix],
      flags: [:error_handling, :underspecs, :unmatched_returns]
    ]
  end
end

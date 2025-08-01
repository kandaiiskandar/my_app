defmodule MyAppWeb.ConnCase do
  @moduledoc """
  This module defines the test case to be used by
  tests that require setting up a connection.

  Such tests rely on `Phoenix.ConnTest` and also
  import other functionality to make it easier
  to build common data structures and query the data layer.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use MyAppWeb.ConnCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      # The default endpoint for testing
      @endpoint MyAppWeb.Endpoint

      use MyAppWeb, :verified_routes

      # Import conveniences for testing with connections
      import Plug.Conn
      import Phoenix.ConnTest
      import MyAppWeb.ConnCase
    end
  end

  setup tags do
    MyApp.DataCase.setup_sandbox(tags)
    {:ok, conn: Phoenix.ConnTest.build_conn()}
  end

  @doc """
  Setup helper that registers and logs in credentials.

      setup :register_and_log_in_credential

  It stores an updated connection and a registered credential in the
  test context.
  """
  def register_and_log_in_credential(%{conn: conn}) do
    credential = MyApp.CredentialsFixtures.credential_fixture()
    %{conn: log_in_credential(conn, credential), credential: credential}
  end

  @doc """
  Logs the given `credential` into the `conn`.

  It returns an updated `conn`.
  """
  def log_in_credential(conn, credential) do
    token = MyApp.Credentials.generate_credential_session_token(credential)

    conn
    |> Phoenix.ConnTest.init_test_session(%{})
    |> Plug.Conn.put_session(:credential_token, token)
  end
end

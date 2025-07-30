defmodule MyAppWeb.CredentialConfirmationInstructionsLiveTest do
  use MyAppWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import MyApp.CredentialsFixtures

  alias MyApp.Credentials
  alias MyApp.Repo

  setup do
    %{credential: credential_fixture()}
  end

  describe "Resend confirmation" do
    test "renders the resend confirmation page", %{conn: conn} do
      {:ok, _lv, html} = live(conn, ~p"/credentials/confirm")
      assert html =~ "Resend confirmation instructions"
    end

    test "sends a new confirmation token", %{conn: conn, credential: credential} do
      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", credential: %{email: credential.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.get_by!(Credentials.CredentialToken, credential_id: credential.id).context == "confirm"
    end

    test "does not send confirmation token if credential is confirmed", %{conn: conn, credential: credential} do
      Repo.update!(Credentials.Credential.confirm_changeset(credential))

      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", credential: %{email: credential.email})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      refute Repo.get_by(Credentials.CredentialToken, credential_id: credential.id)
    end

    test "does not send confirmation token if email is invalid", %{conn: conn} do
      {:ok, lv, _html} = live(conn, ~p"/credentials/confirm")

      {:ok, conn} =
        lv
        |> form("#resend_confirmation_form", credential: %{email: "unknown@example.com"})
        |> render_submit()
        |> follow_redirect(conn, ~p"/")

      assert Phoenix.Flash.get(conn.assigns.flash, :info) =~
               "If your email is in our system"

      assert Repo.all(Credentials.CredentialToken) == []
    end
  end
end

defmodule MyApp.CredentialsTest do
  use MyApp.DataCase

  alias MyApp.Credentials

  import MyApp.CredentialsFixtures
  alias MyApp.Credentials.{Credential, CredentialToken}

  describe "get_credential_by_email/1" do
    test "does not return the credential if the email does not exist" do
      refute Credentials.get_credential_by_email("unknown@example.com")
    end

    test "returns the credential if the email exists" do
      %{id: id} = credential = credential_fixture()
      assert %Credential{id: ^id} = Credentials.get_credential_by_email(credential.email)
    end
  end

  describe "get_credential_by_email_and_password/2" do
    test "does not return the credential if the email does not exist" do
      refute Credentials.get_credential_by_email_and_password("unknown@example.com", "hello world!")
    end

    test "does not return the credential if the password is not valid" do
      credential = credential_fixture()
      refute Credentials.get_credential_by_email_and_password(credential.email, "invalid")
    end

    test "returns the credential if the email and password are valid" do
      %{id: id} = credential = credential_fixture()

      assert %Credential{id: ^id} =
               Credentials.get_credential_by_email_and_password(credential.email, valid_credential_password())
    end
  end

  describe "get_credential!/1" do
    test "raises if id is invalid" do
      assert_raise Ecto.NoResultsError, fn ->
        Credentials.get_credential!(-1)
      end
    end

    test "returns the credential with the given id" do
      %{id: id} = credential = credential_fixture()
      assert %Credential{id: ^id} = Credentials.get_credential!(credential.id)
    end
  end

  describe "register_credential/1" do
    test "requires email and password to be set" do
      {:error, changeset} = Credentials.register_credential(%{})

      assert %{
               password: ["can't be blank"],
               email: ["can't be blank"]
             } = errors_on(changeset)
    end

    test "validates email and password when given" do
      {:error, changeset} = Credentials.register_credential(%{email: "not valid", password: "not valid"})

      assert %{
               email: ["must have the @ sign and no spaces"],
               password: ["should be at least 12 character(s)"]
             } = errors_on(changeset)
    end

    test "validates maximum values for email and password for security" do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Credentials.register_credential(%{email: too_long, password: too_long})
      assert "should be at most 160 character(s)" in errors_on(changeset).email
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates email uniqueness" do
      %{email: email} = credential_fixture()
      {:error, changeset} = Credentials.register_credential(%{email: email})
      assert "has already been taken" in errors_on(changeset).email

      # Now try with the upper cased email too, to check that email case is ignored.
      {:error, changeset} = Credentials.register_credential(%{email: String.upcase(email)})
      assert "has already been taken" in errors_on(changeset).email
    end

    test "registers credentials with a hashed password" do
      email = unique_credential_email()
      {:ok, credential} = Credentials.register_credential(valid_credential_attributes(email: email))
      assert credential.email == email
      assert is_binary(credential.hashed_password)
      assert is_nil(credential.confirmed_at)
      assert is_nil(credential.password)
    end
  end

  describe "change_credential_registration/2" do
    test "returns a changeset" do
      assert %Ecto.Changeset{} = changeset = Credentials.change_credential_registration(%Credential{})
      assert changeset.required == [:password, :email]
    end

    test "allows fields to be set" do
      email = unique_credential_email()
      password = valid_credential_password()

      changeset =
        Credentials.change_credential_registration(
          %Credential{},
          valid_credential_attributes(email: email, password: password)
        )

      assert changeset.valid?
      assert get_change(changeset, :email) == email
      assert get_change(changeset, :password) == password
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "change_credential_email/2" do
    test "returns a credential changeset" do
      assert %Ecto.Changeset{} = changeset = Credentials.change_credential_email(%Credential{})
      assert changeset.required == [:email]
    end
  end

  describe "apply_credential_email/3" do
    setup do
      %{credential: credential_fixture()}
    end

    test "requires email to change", %{credential: credential} do
      {:error, changeset} = Credentials.apply_credential_email(credential, valid_credential_password(), %{})
      assert %{email: ["did not change"]} = errors_on(changeset)
    end

    test "validates email", %{credential: credential} do
      {:error, changeset} =
        Credentials.apply_credential_email(credential, valid_credential_password(), %{email: "not valid"})

      assert %{email: ["must have the @ sign and no spaces"]} = errors_on(changeset)
    end

    test "validates maximum value for email for security", %{credential: credential} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Credentials.apply_credential_email(credential, valid_credential_password(), %{email: too_long})

      assert "should be at most 160 character(s)" in errors_on(changeset).email
    end

    test "validates email uniqueness", %{credential: credential} do
      %{email: email} = credential_fixture()
      password = valid_credential_password()

      {:error, changeset} = Credentials.apply_credential_email(credential, password, %{email: email})

      assert "has already been taken" in errors_on(changeset).email
    end

    test "validates current password", %{credential: credential} do
      {:error, changeset} =
        Credentials.apply_credential_email(credential, "invalid", %{email: unique_credential_email()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "applies the email without persisting it", %{credential: credential} do
      email = unique_credential_email()
      {:ok, credential} = Credentials.apply_credential_email(credential, valid_credential_password(), %{email: email})
      assert credential.email == email
      assert Credentials.get_credential!(credential.id).email != email
    end
  end

  describe "deliver_credential_update_email_instructions/3" do
    setup do
      %{credential: credential_fixture()}
    end

    test "sends token through notification", %{credential: credential} do
      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_update_email_instructions(credential, "current@example.com", url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert credential_token = Repo.get_by(CredentialToken, token: :crypto.hash(:sha256, token))
      assert credential_token.credential_id == credential.id
      assert credential_token.sent_to == credential.email
      assert credential_token.context == "change:current@example.com"
    end
  end

  describe "update_credential_email/2" do
    setup do
      credential = credential_fixture()
      email = unique_credential_email()

      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_update_email_instructions(%{credential | email: email}, credential.email, url)
        end)

      %{credential: credential, token: token, email: email}
    end

    test "updates the email with a valid token", %{credential: credential, token: token, email: email} do
      assert Credentials.update_credential_email(credential, token) == :ok
      changed_credential = Repo.get!(Credential, credential.id)
      assert changed_credential.email != credential.email
      assert changed_credential.email == email
      assert changed_credential.confirmed_at
      assert changed_credential.confirmed_at != credential.confirmed_at
      refute Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not update email with invalid token", %{credential: credential} do
      assert Credentials.update_credential_email(credential, "oops") == :error
      assert Repo.get!(Credential, credential.id).email == credential.email
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not update email if credential email changed", %{credential: credential, token: token} do
      assert Credentials.update_credential_email(%{credential | email: "current@example.com"}, token) == :error
      assert Repo.get!(Credential, credential.id).email == credential.email
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not update email if token expired", %{credential: credential, token: token} do
      {1, nil} = Repo.update_all(CredentialToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Credentials.update_credential_email(credential, token) == :error
      assert Repo.get!(Credential, credential.id).email == credential.email
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end
  end

  describe "change_credential_password/2" do
    test "returns a credential changeset" do
      assert %Ecto.Changeset{} = changeset = Credentials.change_credential_password(%Credential{})
      assert changeset.required == [:password]
    end

    test "allows fields to be set" do
      changeset =
        Credentials.change_credential_password(%Credential{}, %{
          "password" => "new valid password"
        })

      assert changeset.valid?
      assert get_change(changeset, :password) == "new valid password"
      assert is_nil(get_change(changeset, :hashed_password))
    end
  end

  describe "update_credential_password/3" do
    setup do
      %{credential: credential_fixture()}
    end

    test "validates password", %{credential: credential} do
      {:error, changeset} =
        Credentials.update_credential_password(credential, valid_credential_password(), %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{credential: credential} do
      too_long = String.duplicate("db", 100)

      {:error, changeset} =
        Credentials.update_credential_password(credential, valid_credential_password(), %{password: too_long})

      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "validates current password", %{credential: credential} do
      {:error, changeset} =
        Credentials.update_credential_password(credential, "invalid", %{password: valid_credential_password()})

      assert %{current_password: ["is not valid"]} = errors_on(changeset)
    end

    test "updates the password", %{credential: credential} do
      {:ok, credential} =
        Credentials.update_credential_password(credential, valid_credential_password(), %{
          password: "new valid password"
        })

      assert is_nil(credential.password)
      assert Credentials.get_credential_by_email_and_password(credential.email, "new valid password")
    end

    test "deletes all tokens for the given credential", %{credential: credential} do
      _ = Credentials.generate_credential_session_token(credential)

      {:ok, _} =
        Credentials.update_credential_password(credential, valid_credential_password(), %{
          password: "new valid password"
        })

      refute Repo.get_by(CredentialToken, credential_id: credential.id)
    end
  end

  describe "generate_credential_session_token/1" do
    setup do
      %{credential: credential_fixture()}
    end

    test "generates a token", %{credential: credential} do
      token = Credentials.generate_credential_session_token(credential)
      assert credential_token = Repo.get_by(CredentialToken, token: token)
      assert credential_token.context == "session"

      # Creating the same token for another credential should fail
      assert_raise Ecto.ConstraintError, fn ->
        Repo.insert!(%CredentialToken{
          token: credential_token.token,
          credential_id: credential_fixture().id,
          context: "session"
        })
      end
    end
  end

  describe "get_credential_by_session_token/1" do
    setup do
      credential = credential_fixture()
      token = Credentials.generate_credential_session_token(credential)
      %{credential: credential, token: token}
    end

    test "returns credential by token", %{credential: credential, token: token} do
      assert session_credential = Credentials.get_credential_by_session_token(token)
      assert session_credential.id == credential.id
    end

    test "does not return credential for invalid token" do
      refute Credentials.get_credential_by_session_token("oops")
    end

    test "does not return credential for expired token", %{token: token} do
      {1, nil} = Repo.update_all(CredentialToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Credentials.get_credential_by_session_token(token)
    end
  end

  describe "delete_credential_session_token/1" do
    test "deletes the token" do
      credential = credential_fixture()
      token = Credentials.generate_credential_session_token(credential)
      assert Credentials.delete_credential_session_token(token) == :ok
      refute Credentials.get_credential_by_session_token(token)
    end
  end

  describe "deliver_credential_confirmation_instructions/2" do
    setup do
      %{credential: credential_fixture()}
    end

    test "sends token through notification", %{credential: credential} do
      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_confirmation_instructions(credential, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert credential_token = Repo.get_by(CredentialToken, token: :crypto.hash(:sha256, token))
      assert credential_token.credential_id == credential.id
      assert credential_token.sent_to == credential.email
      assert credential_token.context == "confirm"
    end
  end

  describe "confirm_credential/1" do
    setup do
      credential = credential_fixture()

      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_confirmation_instructions(credential, url)
        end)

      %{credential: credential, token: token}
    end

    test "confirms the email with a valid token", %{credential: credential, token: token} do
      assert {:ok, confirmed_credential} = Credentials.confirm_credential(token)
      assert confirmed_credential.confirmed_at
      assert confirmed_credential.confirmed_at != credential.confirmed_at
      assert Repo.get!(Credential, credential.id).confirmed_at
      refute Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not confirm with invalid token", %{credential: credential} do
      assert Credentials.confirm_credential("oops") == :error
      refute Repo.get!(Credential, credential.id).confirmed_at
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not confirm email if token expired", %{credential: credential, token: token} do
      {1, nil} = Repo.update_all(CredentialToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      assert Credentials.confirm_credential(token) == :error
      refute Repo.get!(Credential, credential.id).confirmed_at
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end
  end

  describe "deliver_credential_reset_password_instructions/2" do
    setup do
      %{credential: credential_fixture()}
    end

    test "sends token through notification", %{credential: credential} do
      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_reset_password_instructions(credential, url)
        end)

      {:ok, token} = Base.url_decode64(token, padding: false)
      assert credential_token = Repo.get_by(CredentialToken, token: :crypto.hash(:sha256, token))
      assert credential_token.credential_id == credential.id
      assert credential_token.sent_to == credential.email
      assert credential_token.context == "reset_password"
    end
  end

  describe "get_credential_by_reset_password_token/1" do
    setup do
      credential = credential_fixture()

      token =
        extract_credential_token(fn url ->
          Credentials.deliver_credential_reset_password_instructions(credential, url)
        end)

      %{credential: credential, token: token}
    end

    test "returns the credential with valid token", %{credential: %{id: id}, token: token} do
      assert %Credential{id: ^id} = Credentials.get_credential_by_reset_password_token(token)
      assert Repo.get_by(CredentialToken, credential_id: id)
    end

    test "does not return the credential with invalid token", %{credential: credential} do
      refute Credentials.get_credential_by_reset_password_token("oops")
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end

    test "does not return the credential if token expired", %{credential: credential, token: token} do
      {1, nil} = Repo.update_all(CredentialToken, set: [inserted_at: ~N[2020-01-01 00:00:00]])
      refute Credentials.get_credential_by_reset_password_token(token)
      assert Repo.get_by(CredentialToken, credential_id: credential.id)
    end
  end

  describe "reset_credential_password/2" do
    setup do
      %{credential: credential_fixture()}
    end

    test "validates password", %{credential: credential} do
      {:error, changeset} =
        Credentials.reset_credential_password(credential, %{
          password: "not valid",
          password_confirmation: "another"
        })

      assert %{
               password: ["should be at least 12 character(s)"],
               password_confirmation: ["does not match password"]
             } = errors_on(changeset)
    end

    test "validates maximum values for password for security", %{credential: credential} do
      too_long = String.duplicate("db", 100)
      {:error, changeset} = Credentials.reset_credential_password(credential, %{password: too_long})
      assert "should be at most 72 character(s)" in errors_on(changeset).password
    end

    test "updates the password", %{credential: credential} do
      {:ok, updated_credential} = Credentials.reset_credential_password(credential, %{password: "new valid password"})
      assert is_nil(updated_credential.password)
      assert Credentials.get_credential_by_email_and_password(credential.email, "new valid password")
    end

    test "deletes all tokens for the given credential", %{credential: credential} do
      _ = Credentials.generate_credential_session_token(credential)
      {:ok, _} = Credentials.reset_credential_password(credential, %{password: "new valid password"})
      refute Repo.get_by(CredentialToken, credential_id: credential.id)
    end
  end

  describe "inspect/2 for the Credential module" do
    test "does not include password" do
      refute inspect(%Credential{password: "123456"}) =~ "password: \"123456\""
    end
  end
end

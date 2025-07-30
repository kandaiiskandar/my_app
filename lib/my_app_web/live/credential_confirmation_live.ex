defmodule MyAppWeb.CredentialConfirmationLive do
  use MyAppWeb, :live_view

  alias MyApp.Credentials

  def render(%{live_action: :edit} = assigns) do
    ~H"""
    <div class="mx-auto max-w-sm">
      <.header class="text-center">Confirm Account</.header>

      <.simple_form for={@form} id="confirmation_form" phx-submit="confirm_account">
        <input type="hidden" name={@form[:token].name} value={@form[:token].value} />
        <:actions>
          <.button phx-disable-with="Confirming..." class="w-full">Confirm my account</.button>
        </:actions>
      </.simple_form>

      <p class="text-center mt-4">
        <.link href={~p"/credentials/register"}>Register</.link>
        | <.link href={~p"/credentials/log_in"}>Log in</.link>
      </p>
    </div>
    """
  end

  def mount(%{"token" => token}, _session, socket) do
    form = to_form(%{"token" => token}, as: "credential")
    {:ok, assign(socket, form: form), temporary_assigns: [form: nil]}
  end

  # Do not log in the credential after confirmation to avoid a
  # leaked token giving the credential access to the account.
  def handle_event("confirm_account", %{"credential" => %{"token" => token}}, socket) do
    case Credentials.confirm_credential(token) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Credential confirmed successfully.")
         |> redirect(to: ~p"/")}

      :error ->
        # If there is a current credential and the account was already confirmed,
        # then odds are that the confirmation link was already visited, either
        # by some automation or by the credential themselves, so we redirect without
        # a warning message.
        case socket.assigns do
          %{current_credential: %{confirmed_at: confirmed_at}} when not is_nil(confirmed_at) ->
            {:noreply, redirect(socket, to: ~p"/")}

          %{} ->
            {:noreply,
             socket
             |> put_flash(:error, "Credential confirmation link is invalid or it has expired.")
             |> redirect(to: ~p"/")}
        end
    end
  end
end

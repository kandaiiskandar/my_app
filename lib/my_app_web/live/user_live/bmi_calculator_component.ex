defmodule MyAppWeb.UserLive.BmiCalculatorComponent do
  use MyAppWeb, :live_component

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.header>
        {@title}
        <:subtitle>Calculate BMI (Body Mass Index) for {@user.name}</:subtitle>
      </.header>

      <.simple_form
        for={@form}
        id="bmi-calculator-form"
        phx-target={@myself}
        phx-change="calculate"
        phx-submit="close"
      >
        <.input field={@form[:height]} type="number" label="Height (cm)" step="0.1" min="1" />
        <.input field={@form[:weight]} type="number" label="Weight (kg)" step="0.1" min="1" />

        <div :if={@bmi} class="mt-6 p-4 bg-gray-50 rounded-lg">
          <h3 class="text-lg font-semibold text-gray-900 mb-2">BMI Result</h3>
          <div class="text-2xl font-bold mb-2" style={"color: #{@bmi_color}"}>
            {@bmi}
          </div>
          <div class="text-sm font-medium" style={"color: #{@bmi_color}"}>
            {@bmi_category}
          </div>
          <div class="mt-3 text-sm text-gray-600">
            <p><strong>BMI Categories:</strong></p>
            <ul class="mt-1 space-y-1">
              <li>Underweight: Less than 18.5</li>
              <li>Normal weight: 18.5 - 24.9</li>
              <li>Overweight: 25.0 - 29.9</li>
              <li>Obese: 30.0 and above</li>
            </ul>
          </div>
        </div>

        <:actions>
          <.button type="submit">Close</.button>
        </:actions>
      </.simple_form>
    </div>
    """
  end

  @impl true
  def update(assigns, socket) do
    {:ok,
     socket
     |> assign(assigns)
     |> assign(:bmi, nil)
     |> assign(:bmi_category, nil)
     |> assign(:bmi_color, "#000000")
     |> assign_new(:form, fn ->
       to_form(%{"height" => "", "weight" => ""}, as: :bmi)
     end)}
  end

  @impl true
  def handle_event("calculate", %{"bmi" => bmi_params}, socket) do
    height = parse_float(bmi_params["height"])
    weight = parse_float(bmi_params["weight"])

    {bmi, category, color} = calculate_bmi(height, weight)

    {:noreply,
     socket
     |> assign(:bmi, bmi)
     |> assign(:bmi_category, category)
     |> assign(:bmi_color, color)
     |> assign(:form, to_form(bmi_params, as: :bmi))}
  end

  def handle_event("close", _params, socket) do
    {:noreply, push_patch(socket, to: socket.assigns.patch)}
  end

  defp parse_float(value) when is_binary(value) do
    case Float.parse(value) do
      {float, _} when float > 0 -> float
      _ -> nil
    end
  end

  defp parse_float(_), do: nil

  defp calculate_bmi(height, weight) when is_number(height) and is_number(weight) do
    # Convert height from cm to meters
    height_m = height / 100
    bmi = weight / (height_m * height_m)
    bmi_rounded = Float.round(bmi, 1)

    {category, color} =
      case bmi_rounded do
        bmi when bmi < 18.5 -> {"Underweight", "#3B82F6"}
        bmi when bmi < 25.0 -> {"Normal weight", "#10B981"}
        bmi when bmi < 30.0 -> {"Overweight", "#F59E0B"}
        _ -> {"Obese", "#EF4444"}
      end

    {bmi_rounded, category, color}
  end

  defp calculate_bmi(_, _), do: {nil, nil, "#000000"}
end

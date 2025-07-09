defmodule MyApp.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  schema "users" do
    field :name, :string
    field :age, :integer
    field :dob, :date
    field :address, :string
    field :gender, :string

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(user, attrs) do
    user
    |> cast(attrs, [:name, :age, :dob, :address, :gender])
    |> validate_required([:name, :age])
    |> validate_number(:age, greater_than: 0, less_than: 50)
    |> validate_inclusion(:gender, ["male", "female"])
  end
end

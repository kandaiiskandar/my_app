defmodule MyApp.Repo.Migrations.AddUserDetails do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :dob, :date
      add :address, :string
      add :gender, :string
    end
  end
end

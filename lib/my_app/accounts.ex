defmodule MyApp.Accounts do
  @moduledoc """
  The Accounts context.
  """

  import Ecto.Query, warn: false
  alias MyApp.Repo

  alias MyApp.Accounts.User

  @doc """
  Returns the list of users.

  ## Examples

      iex> list_users()
      [%User{}, ...]

  """
  def list_users do
    Repo.all(User)
  end

  @doc """
  Gets a single user.

  Raises `Ecto.NoResultsError` if the User does not exist.

  ## Examples

      iex> get_user!(123)
      %User{}

      iex> get_user!(456)
      ** (Ecto.NoResultsError)

  """
  def get_user!(id), do: Repo.get!(User, id)

  def get_user(id), do: Repo.get(User, id)

  @doc """
  Creates a user.

  ## Examples

      attrs = %{name: "John", age: 20}
      iex> create_user(%{field: value})
      {:ok, %User{}}

      iex> create_user(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a user.

  ## Examples

      iex> update_user(user, %{field: new_value})
      {:ok, %User{}}

      iex> update_user(user, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a user.

  ## Examples

      iex> delete_user(user)
      {:ok, %User{}}

      iex> delete_user(user)
      {:error, %Ecto.Changeset{}}

  """
  def delete_user(%User{} = user) do
    Repo.delete(user)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking user changes.

  ## Examples

      iex> change_user(user)
      %Ecto.Changeset{data: %User{}}

  """
  def change_user(%User{} = user, attrs \\ %{}) do
    User.changeset(user, attrs)
  end

  # def user_gender(%User{gender: "male"}) do
  #   "User is male"
  # end

  # def user_gender(%User{gender: "female"}) do
  #   "User is female"
  # end

  # def user_gender(_user) do
  #   "Unknown gender"
  # end

  def user_gender(%User{gender: gender}) do
    case gender do
      "male" -> "User is male"
      "female" -> "User is female"
      _ -> "Unknown gender"
    end
  end

  def user_age_range(%User{age: age}) when age < 18 do
    "User is a minor"
  end

  def user_age_range(%User{age: age}) when age >= 18 and age <= 65 do
    "User is an adult"
  end

  def user_age_range(_user) do
    "Unknown age range"
  end

  def user_details(%User{} = user) do
    user_gender(user) <> " " <> user_age_range(user)
  end

  # ========== PIPE OPERATOR EXAMPLES ==========

  @doc """
  Example 1: Basic pipe chain - transforming data step by step
  """
  def format_user_info(%User{} = user) do
    user
    |> user_details()
    |> String.upcase()
    |> String.replace(" ", "_")
  end

  @doc """
  Example 2: Pipe with conditional logic and error handling
  """
  def create_and_format_user(attrs) do
    attrs
    |> create_user()
    |> case do
      {:ok, user} ->
        formatted_info =
          user
          |> format_user_info()

        {:ok, formatted_info}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  @doc """
  Example 3: Complex pipe chain with multiple transformations
  """
  def process_user_list(user_ids) do
    user_ids
    |> Enum.map(&get_user/1)
    |> Enum.filter(&(!is_nil(&1)))
    |> Enum.map(&user_details/1)
    |> Enum.join(", ")
    |> String.trim()
  end

  @doc """
  Example 4: Pipe with database operations
  """
  def update_user_with_validation(user_id, attrs) do
    user_id
    |> get_user()
    |> case do
      nil ->
        {:error, :user_not_found}

      user ->
        user
        |> update_user(attrs)
        |> case do
          {:ok, updated_user} ->
            updated_user
            |> user_details()
            |> then(&{:ok, updated_user, &1})

          error ->
            error
        end
    end
  end

  @doc """
  Example 5: Pipe with anonymous functions and then/2
  """
  def analyze_user(%User{} = user) do
    user
    |> then(fn u -> %{name: u.name, age: u.age, gender: u.gender} end)
    |> then(fn data -> Map.put(data, :category, user_age_range(user)) end)
    |> then(fn data -> Map.put(data, :gender_info, user_gender(user)) end)
    |> then(fn data -> Map.put(data, :is_adult, data.age >= 18) end)
  end

  @doc """
  Example 6: Pipe with Enum functions for bulk operations
  """
  def get_adult_users_summary do
    User
    |> Repo.all()
    |> Enum.filter(fn user -> user.age >= 18 end)
    |> Enum.map(&user_details/1)
    |> Enum.group_by(&String.contains?(&1, "male"))
    |> Enum.map(fn {is_male, details} ->
      {if(is_male, do: "male", else: "female"), length(details)}
    end)
    |> Enum.into(%{})
  end

  @doc """
  Example 7: Pipe with custom helper functions
  """
  def create_user_profile(attrs) do
    attrs
    |> validate_user_attrs()
    |> create_user()
    |> handle_user_creation()
    |> generate_profile_summary()
  end

  # Helper functions for Example 7
  defp validate_user_attrs(attrs) do
    attrs
    |> Map.put_new(:age, 0)
    |> Map.put_new(:gender, "unknown")
  end

  defp handle_user_creation({:ok, user}), do: {:ok, user}
  defp handle_user_creation({:error, changeset}), do: {:error, changeset}

  defp generate_profile_summary({:ok, user}) do
    summary =
      user
      |> user_details()
      |> String.downcase()

    {:ok, user, summary}
  end

  defp generate_profile_summary({:error, changeset}), do: {:error, changeset}

  @doc """
  Example 8: Pipe with tap/2 for side effects (debugging, logging)
  """
  def debug_user_creation(attrs) do
    attrs
    |> tap(&IO.inspect(&1, label: "Input attrs"))
    |> create_user()
    |> tap(fn
      {:ok, user} -> IO.puts("User created successfully: #{user.name}")
      {:error, _} -> IO.puts("Failed to create user")
    end)
    |> case do
      {:ok, user} ->
        user
        |> tap(&IO.inspect(user_details(&1), label: "User details"))
        |> then(&{:ok, &1})

      error ->
        error
    end
  end

  def format_user_name(%User{name: name}) do
    name |> String.upcase() |> String.replace(" ", "_")
  end
end

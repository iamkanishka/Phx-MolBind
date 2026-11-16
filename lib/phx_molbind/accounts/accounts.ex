defmodule PhxMolbind.Accounts do
  @moduledoc """
  The Accounts context.

  Owns wallet-identified users and their login sessions. There is
  intentionally no email/password flow here — identity is proven via
  `PhxMolbind.EthAuth.Auth.verify_signature/2`, not stored here.
  """

  import Ecto.Query, warn: false

  alias PhxMolbind.Repo
  alias PhxMolbind.Accounts.{User, UserToken}

  ## Users

  @doc "Fetches a user by their (case-insensitive) wallet address, or nil."
  def get_user_by_address(address) when is_binary(address) do
    Repo.get_by(User, address: String.downcase(address))
  end

  @doc "Fetches a user by id, or nil if not found."
  def get_user(id), do: Repo.get(User, id)

  @doc "Fetches a user by id, raising if not found."
  def get_user!(id), do: Repo.get!(User, id)

  @doc "Creates a user for a freshly-verified wallet address."
  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  @doc "Updates an existing user (profile fields, last_login_at, ...)."
  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Finds the user for `address`, creating one if this is their first login.
  Always stamps `last_login_at`. This is the single entry point the login
  flow should call once a wallet signature has been verified.
  """
  def find_or_create_user_by_address(address) do
    now = DateTime.utc_now()

    case get_user_by_address(address) do
      nil -> create_user(%{address: address, last_login_at: now})
      user -> update_user(user, %{last_login_at: now})
    end
  end

  @doc """
  Updates the editable profile fields (username, bio, photo) for `user`.
  Bio and photo live inside the `metadata` map rather than as their own
  columns, since they're free-form and unlikely to need querying on.
  """
  def update_profile(%User{} = user, attrs) do
    metadata =
      Map.merge(user.metadata || %{}, %{
        "bio" => Map.get(attrs, "bio", Map.get(user.metadata || %{}, "bio")),
        "photo_url" => Map.get(attrs, "photo_url", Map.get(user.metadata || %{}, "photo_url"))
      })

    user
    |> User.profile_changeset(%{username: Map.get(attrs, "username"), metadata: metadata})
    |> Repo.update()
  end

  ## Avatar

  @doc "The user's stored avatar file name, if it is a valid one."
  def avatar_name(%User{metadata: metadata}) do
    name = Map.get(metadata || %{}, "avatar")
    if PhxMolbind.Avatars.valid_name?(name), do: name, else: nil
  end

  @doc "URL to show for the user's picture: uploaded avatar first, then the profile photo URL."
  def avatar_url(%User{} = user) do
    case avatar_name(user) do
      nil -> Map.get(user.metadata || %{}, "photo_url")
      name -> PhxMolbind.Avatars.url(name)
    end
  end

  @doc """
  Stores image bytes as the user's avatar (replacing and deleting any previous
  one). Returns `{:ok, user}` or `{:error, :unsupported | :storage | changeset}`.
  """
  def set_avatar(%User{} = user, binary) do
    with {:ok, name} <- PhxMolbind.Avatars.store(binary) do
      previous = avatar_name(user)

      case update_user(user, %{metadata: Map.put(user.metadata || %{}, "avatar", name)}) do
        {:ok, updated} ->
          if previous, do: PhxMolbind.Avatars.delete(previous)
          {:ok, updated}

        {:error, _} = error ->
          # Don't orphan the file we just wrote.
          PhxMolbind.Avatars.delete(name)
          error
      end
    end
  end

  @doc "Removes the user's uploaded avatar (file and reference)."
  def clear_avatar(%User{} = user) do
    previous = avatar_name(user)

    with {:ok, updated} <-
           update_user(user, %{metadata: Map.delete(user.metadata || %{}, "avatar")}) do
      if previous, do: PhxMolbind.Avatars.delete(previous)
      {:ok, updated}
    end
  end

  ## Onboarding

  @onboarding_states ~w(dismissed restarted)

  @doc """
  The user's saved onboarding state: `"dismissed"`, `"restarted"` or `nil`
  (never touched). Stored in the free-form `metadata` map, so no schema
  change is needed.
  """
  def onboarding_state(%User{metadata: metadata}) do
    case Map.get(metadata || %{}, "onboarding") do
      state when state in @onboarding_states -> state
      _ -> nil
    end
  end

  @doc """
  Whether the getting-started guide should show. Users who dismissed it never
  see it again until they restart it; users who restarted it always see it;
  everyone else sees it only while they have no saved generation runs, so
  returning users are not nagged.
  """
  def show_onboarding?(%User{} = user, runs_count) when is_integer(runs_count) do
    case onboarding_state(user) do
      "dismissed" -> false
      "restarted" -> true
      nil -> runs_count == 0
    end
  end

  @doc "Saves `\"dismissed\"` or `\"restarted\"`, preserving all other metadata."
  def set_onboarding(%User{} = user, state) when state in @onboarding_states do
    update_user(user, %{metadata: Map.put(user.metadata || %{}, "onboarding", state)})
  end

  ## Session tokens

  @doc "Generates a new session token for `user` and persists it."
  def generate_user_session_token(user) do
    {token, user_token} = UserToken.build_session_token(user)
    Repo.insert!(user_token)
    token
  end

  @doc """
  Fetches the user for a raw session token, or nil if the token is
  missing/expired.
  """
  def get_user_by_session_token(token) do
    {:ok, query} = UserToken.verify_session_token_query(token)
    Repo.one(query)
  end

  @doc "Deletes a specific session token (used on logout)."
  def delete_user_session_token(token) do
    Repo.delete_all(UserToken.by_token_and_context_query(token, "session"))
    :ok
  end

  @doc "Deletes every session token for a user (e.g. on account changes)."
  def delete_all_user_sessions(%User{} = user) do
    Repo.delete_all(UserToken.by_user_and_contexts_query(user, ["session"]))
    :ok
  end

  ## Session management

  @doc """
  Lists the user's unexpired sessions. Each entry has an opaque `:id` (a
  truncated SHA-256 of the token — the raw token is never exposed), the
  creation time, and `:current?` for the session making this request.
  """
  def list_user_sessions(%User{} = user, current_token) do
    user.id
    |> UserToken.valid_sessions_for_user_query()
    |> Repo.all()
    |> Enum.map(fn t ->
      %{
        id: session_ref(t.token),
        inserted_at: t.inserted_at,
        current?: same_token?(t.token, current_token)
      }
    end)
  end

  @doc """
  Revokes one of the user's *other* sessions by its `:id`. Returns
  `{:ok, raw_token}` (so the caller can disconnect its live sockets),
  `{:error, :current_session}` or `{:error, :not_found}`. Ids belonging to
  other users never match.
  """
  def revoke_user_session(%User{} = user, ref, current_token) when is_binary(ref) do
    tokens = Repo.all(UserToken.valid_sessions_for_user_query(user.id))

    case Enum.find(tokens, &(session_ref(&1.token) == ref)) do
      nil ->
        {:error, :not_found}

      %{token: token} when is_binary(current_token) and token == current_token ->
        {:error, :current_session}

      %{id: id, token: token} ->
        Repo.delete_all(from t in UserToken, where: t.id == ^id and t.user_id == ^user.id)
        {:ok, token}
    end
  end

  def revoke_user_session(_user, _ref, _current_token), do: {:error, :not_found}

  @doc "Deletes every session except `current_token`; returns the revoked raw tokens."
  def delete_other_sessions(%User{} = user, current_token) do
    others =
      user.id
      |> UserToken.valid_sessions_for_user_query()
      |> Repo.all()
      |> Enum.reject(&same_token?(&1.token, current_token))

    ids = Enum.map(others, & &1.id)
    Repo.delete_all(from t in UserToken, where: t.id in ^ids and t.user_id == ^user.id)
    Enum.map(others, & &1.token)
  end

  @doc """
  Permanently deletes the user. Foreign keys cascade, so sessions, chat
  messages, generation runs, collections and saved items all go with them.
  """
  def delete_account(%User{} = user) do
    with {:ok, deleted} <- Repo.delete(user) do
      # The row is gone; remove the picture file too.
      if name = avatar_name(user), do: PhxMolbind.Avatars.delete(name)
      {:ok, deleted}
    end
  end

  defp session_ref(token) do
    :crypto.hash(:sha256, token) |> Base.url_encode64(padding: false) |> binary_part(0, 16)
  end

  defp same_token?(_token, nil), do: false

  defp same_token?(token, current) when is_binary(current),
    do: Plug.Crypto.secure_compare(token, current)

  defp same_token?(_token, _other), do: false
end

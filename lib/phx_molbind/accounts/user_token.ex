defmodule PhxMolbind.Accounts.UserToken do
  @moduledoc """
  Opaque, random session tokens for logged-in users.

  The token is 32 bytes of CSPRNG output (192+ bits of entropy) — infeasible
  to guess — and is compared against the stored value on every request. The
  same value is what's placed in the signed/encrypted session cookie by
  `PhxMolbindWeb.UserAuth`, so a database read alone (without the signed
  cookie) is not enough to hijack a session.
  """
  use Ecto.Schema
  import Ecto.Query

  @rand_size 32

  # Sessions are valid for 60 days, matching the "remember me" cookie in
  # PhxMolbindWeb.UserAuth.
  @session_validity_in_days 60

  schema "users_tokens" do
    field :token, :binary
    field :context, :string
    belongs_to :user, PhxMolbind.Accounts.User

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc """
  Builds an opaque token and its Ecto schema struct for insertion, scoped to
  the `"session"` context.
  """
  def build_session_token(user) do
    token = :crypto.strong_rand_bytes(@rand_size)
    {token, %__MODULE__{token: token, context: "session", user_id: user.id}}
  end

  @doc """
  Returns a query that finds the user for a given session token, provided
  the token has not expired.
  """
  def verify_session_token_query(token) do
    query =
      from token in by_token_and_context_query(token, "session"),
        join: user in assoc(token, :user),
        where: token.inserted_at > ago(@session_validity_in_days, "day"),
        select: user

    {:ok, query}
  end

  @doc "Returns a query for the user's unexpired session tokens, newest first."
  def valid_sessions_for_user_query(user_id) do
    from t in PhxMolbind.Accounts.UserToken,
      where:
        t.user_id == ^user_id and t.context == "session" and
          t.inserted_at > ago(@session_validity_in_days, "day"),
      order_by: [desc: t.inserted_at, desc: t.id]
  end

  @doc "Returns a query to fetch a token by its raw value and context."
  def by_token_and_context_query(token, context) do
    from PhxMolbind.Accounts.UserToken, where: [token: ^token, context: ^context]
  end

  @doc "Returns a query to fetch all tokens for a given user and contexts."
  def by_user_and_contexts_query(user, contexts) do
    from t in PhxMolbind.Accounts.UserToken,
      where: t.user_id == ^user.id and t.context in ^contexts
  end
end

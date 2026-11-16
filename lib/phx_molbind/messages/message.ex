defmodule PhxMolbind.Messages.Message do
  @moduledoc """
  A single message in the shared research chat lobby.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "messages" do
    field :body, :string
    field :edited_at, :utc_datetime_usec
    # Set only by `molecule_changeset/2` (trusted server code), never cast
    # from user input, so a client cannot forge a molecule card.
    field :smiles, :string
    belongs_to :user, PhxMolbind.Accounts.User
    belongs_to :reply_to, __MODULE__
    has_many :reactions, PhxMolbind.Messages.Reaction

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  @doc false
  def changeset(message, attrs) do
    message
    |> cast(attrs, [:body, :user_id, :reply_to_id])
    |> validate_required([:body, :user_id])
    |> validate_length(:body, min: 1, max: 2000)
    |> update_change(:body, &String.trim/1)
    |> assoc_constraint(:reply_to)
  end

  @smiles_chars ~r/\A[A-Za-z0-9@+\-\[\]\(\)=#$:\/\\%.*]+\z/

  @doc """
  Changeset for a molecule card. `smiles` is passed in by trusted code that
  has already derived it from a record the sharer owns; this only checks its
  shape. The preliminary character check is not chemical validation.
  """
  def molecule_changeset(message, attrs, smiles) do
    message
    |> changeset(attrs)
    |> put_change(:smiles, smiles)
    |> validate_length(:smiles, min: 1, max: 500)
    |> validate_format(:smiles, @smiles_chars)
  end

  @doc "Changeset for editing the body of an existing message."
  def edit_changeset(message, attrs) do
    message
    |> cast(attrs, [:body])
    |> validate_required([:body])
    |> update_change(:body, &String.trim/1)
    |> validate_length(:body, min: 1, max: 2000)
    |> put_change(:edited_at, DateTime.utc_now())
  end
end

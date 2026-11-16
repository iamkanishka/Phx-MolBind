defmodule PhxMolbindWeb.ShareLive.Show do
  @moduledoc """
  Public, read-only view of a shared run or collection (`/s/:token`).

  No sign-in is required and none is assumed: this LiveView has no
  authentication hook, so even a signed-in visitor sees the same minimal page
  without the application shell. It shows only what
  `PhxMolbind.Sharing.resolve/1` whitelists.
  """
  use PhxMolbindWeb, :live_view

  alias PhxMolbind.Sharing
  alias PhxMolbindWeb.ShareLive.NotFound

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    case Sharing.resolve(token) do
      {:ok, shared} ->
        {:ok,
         socket
         |> assign(:page_title, "Shared #{shared.kind}")
         |> assign(:shared, shared)}

      {:error, :not_found} ->
        raise NotFound
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="mx-auto max-w-5xl px-4 py-8">
      <header>
        <p class="text-xs font-medium uppercase tracking-wide text-body dark:text-bodydark">
          Shared from MolBind · read-only
        </p>
        <h1 class="mt-1 font-display text-2xl font-semibold text-black dark:text-white">
          {@shared.title}
        </h1>
        <p class="mt-2 text-sm text-body dark:text-bodydark">
          You are viewing a link someone chose to share. It shows only what is listed here and cannot be edited. Scores, where present, are values reported by a generation model, not experimental measurements.
        </p>
      </header>

      <%= if @shared.kind == "run" do %>
        <section class="mt-6" aria-labelledby="start-heading">
          <h2 id="start-heading" class="font-medium text-black dark:text-white">Starting molecule</h2>
          <.molecule_canvas id="shared-start" smiles={@shared.starting_smiles} size={240} />
          <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">
            {@shared.starting_smiles}
          </p>
        </section>

        <section class="mt-6" aria-labelledby="params-heading">
          <h2 id="params-heading" class="font-medium text-black dark:text-white">Parameters</h2>
          <dl class="mt-2 grid grid-cols-1 gap-3 text-sm sm:grid-cols-3">
            <div :for={{label, value} <- @shared.parameters}>
              <dt class="font-medium text-black dark:text-white">{label}</dt>
              <dd class="text-body dark:text-bodydark">{value}</dd>
            </div>
          </dl>
          <p class="mt-2 text-xs text-body dark:text-bodydark">Run saved {@shared.created_on}.</p>
        </section>

        <section class="mt-6" aria-labelledby="cands-heading">
          <h2 id="cands-heading" class="font-medium text-black dark:text-white">
            Candidates ({length(@shared.candidates)})
          </h2>
          <ul class="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <li
              :for={{c, i} <- Enum.with_index(@shared.candidates)}
              id={"shared-candidate-#{i}"}
              class="rounded-lg border border-stroke bg-white p-3 dark:border-strokedark dark:bg-[#181818]"
            >
              <p class="text-sm font-medium text-black dark:text-white">Candidate {i + 1}</p>
              <.molecule_canvas id={"shared-cand-#{i}"} smiles={c.structure} size={260} />
              <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{c.structure}</p>
              <p class="mt-1 text-sm text-black dark:text-white">
                {@shared.property_name} score: <span class="font-mono">{format_score(c.score)}</span>
              </p>
            </li>
          </ul>
        </section>
      <% else %>
        <section class="mt-6" aria-labelledby="items-heading">
          <h2 id="items-heading" class="font-medium text-black dark:text-white">
            Saved molecules ({length(@shared.items)})
          </h2>
          <p :if={@shared.items == []} class="mt-2 text-sm text-body dark:text-bodydark">
            This collection is empty.
          </p>
          <ul class="mt-3 grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
            <li
              :for={{item, i} <- Enum.with_index(@shared.items)}
              id={"shared-item-#{i}"}
              class="rounded-lg border border-stroke bg-white p-3 dark:border-strokedark dark:bg-[#181818]"
            >
              <.molecule_canvas id={"shared-item-canvas-#{i}"} smiles={item.smiles} size={260} />
              <p class="mt-2 break-all font-mono text-xs text-black dark:text-white">{item.smiles}</p>
              <p class="mt-1 text-xs text-body dark:text-bodydark">
                <%= if item.score do %>
                  {item.property_name} score:
                  <span class="font-mono">{format_score(item.score)}</span>
                <% else %>
                  No score recorded
                <% end %>
              </p>
            </li>
          </ul>
        </section>
      <% end %>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :smiles, :string, required: true
  attr :size, :integer, default: 240

  defp molecule_canvas(assigns) do
    ~H"""
    <.structure_viewer
      id={"#{@id}-viewer"}
      canvas_id={@id}
      smiles={@smiles}
      size={@size}
      filename="molbind-shared-structure.png"
    />
    """
  end

  defp format_score(score) when is_number(score),
    do: :erlang.float_to_binary(score * 1.0, decimals: 4)

  defp format_score(_), do: "not reported"
end

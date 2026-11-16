defmodule PhxMolbindWeb.ExportController do
  @moduledoc """
  CSV downloads. Both actions are behind `require_authenticated_user` and look
  records up through user-scoped context functions, so another user's run or
  collection answers 404 exactly like a missing one.
  """
  use PhxMolbindWeb, :controller

  alias PhxMolbind.Collections
  alias PhxMolbind.Molecules.Molecules

  def run(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         %{} = run <- Molecules.get_history_entry(user.id, int_id) do
      send_csv(conn, "molbind-run-#{run.id}.csv", Molecules.run_to_csv(run))
    else
      _ -> not_found(conn)
    end
  end

  def collection(conn, %{"id" => id}) do
    user = conn.assigns.current_user

    with {int_id, ""} <- Integer.parse(id),
         %{} = collection <- Collections.get_collection(user.id, int_id) do
      csv = user.id |> Collections.list_items(collection.id) |> Collections.items_to_csv()
      send_csv(conn, "molbind-collection-#{collection.id}.csv", csv)
    else
      _ -> not_found(conn)
    end
  end

  defp send_csv(conn, filename, csv) do
    send_download(conn, {:binary, csv},
      filename: filename,
      content_type: "text/csv; charset=utf-8"
    )
  end

  defp not_found(conn), do: conn |> put_status(:not_found) |> text("Not found")
end

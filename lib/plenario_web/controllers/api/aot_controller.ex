defmodule PlenarioWeb.Api.AotController do
  use PlenarioWeb, :api_controller

  import Ecto.Query
  import Geo.PostGIS, only: [st_intersects: 2]
  import PlenarioWeb.Api.Plugs
  import PlenarioWeb.Api.Utils, only: [render_page: 6]

  alias Plenario.Repo
  alias PlenarioAot.{AotData, AotMeta, AotObservation}

  require Logger

  plug :check_page
  plug :check_page_size, default_page_size: 500, page_size_limit: 5000

  defp parse_bbox(value, conn) do
    try do
      Poison.decode!(value) |> Geo.JSON.decode()
    rescue
      _ -> conn |> Explode.with(400, "Unable to parse bounding box JSON or generate Geo object")
    end
  end

  defp parse_time_range(value) do
    try do
      json = Poison.decode!(value)

      lower = parse_datetime(json["lower"]) |> Timex.to_erl()
      {ymd, {h, m, s}} = lower
      lower = {ymd, {h, m, s, 0}}

      upper = parse_datetime(json["upper"]) |> Timex.to_erl()
      {ymd, {h, m, s}} = upper
      upper = {ymd, {h, m, s, 0}}

      %Postgrex.Range{lower: lower, upper: upper}
    rescue
      _ -> nil
    end
  end

  defp parse_datetime(value) do
    try do
      Timex.parse!(value, "{ISO:Extended:Z}")
    rescue
      _ ->
        try do
          Timex.parse!(value, "{ISO:Extended}")
        rescue
          _ ->
            try do
              Timex.parse!(value, "{ISOdate} {ISOtime}")
            rescue
              _ -> nil
            end
        end
    end
  end

  defp handle_conn_params(conn) do
    # handle meta level filters: network_name, bbox
    metas = from m in AotMeta
    metas =
      case Map.get(conn.params, "network_name") do
        nil -> metas
        value ->
          case is_list(value) do
            true -> from m in metas, where: m.network_name in ^value or m.slug in ^value
            false -> from m in metas, where: m.network_name == ^value or m.slug == ^value
          end
      end
    metas =
      case Map.get(conn.params, "bbox") do
        nil -> metas
        value ->
          bbox = parse_bbox(value, conn)
          from m in metas, where: st_intersects(m.bbox, ^bbox)
      end
    meta_ids =
      try do
        Repo.all(
          from m in metas,
          select: m.id,
          distinct: m.id
        )
      rescue
        _ -> nil
      end

    case meta_ids do
      nil -> conn |> Explode.with(400, "Unable to execute bounding box query")
      _ -> meta_ids
    end

    # handle data level filters: node_id, timestamp
    data = from d in AotData, where: d.aot_meta_id in ^meta_ids
    data =
      case Map.get(conn.params, "node_id") do
        nil -> data
        value ->
          case is_list(value) do
            true -> from d in data, where: d.node_id in ^value
            false -> from d in data, where: d.node_id == ^value
          end
      end
    data =
      case Map.get(conn.params, "timestamp") do
        nil -> data
        value ->
          [op, term] =
            case Regex.match?(~r/^in|eq|gt|ge|lt|le\:.*$/, value) do
              true ->  String.split(value, ":", parts: 2)
              false -> ["eq", value]
            end

          term = case op do
            "in" -> parse_time_range(term)
            _ -> parse_datetime(term)
          end
          case term do
            nil -> data
            term ->
              case op do
                "eq" -> from d in data, where: fragment("? = ?::timestamp", d.timestamp, ^term)
                "gt" -> from d in data, where: fragment("? > ?::timestamp", d.timestamp, ^term)
                "ge" -> from d in data, where: fragment("? >= ?::timestamp", d.timestamp, ^term)
                "lt" -> from d in data, where: fragment("? < ?::timestamp", d.timestamp, ^term)
                "le" -> from d in data, where: fragment("? <= ?::timestamp", d.timestamp, ^term)
                "in" -> from d in data, where: fragment("? <@ ?::tsrange", d.timestamp, ^term)
                _ -> data
              end
          end
      end

    # TODO: handle observations
    # handle observation level filters: sensor, {observation}
    obs_data_ids =
      case Map.get(conn.params, "sensor") do
        nil ->
          nil

        value ->
          data_ids = Repo.all(
            from d in data,
            select: d.id,
            distinct: d.id
          )
          case is_list(value) do
            true ->
              Repo.all(
                from o in AotObservation,
                where: o.aot_data_id in ^data_ids,
                where: o.sensor in ^value,
                select: o.aot_data_id,
                distinct: o.aot_data_id
              )
            false ->
              Repo.all(
                from o in AotObservation,
                where: o.aot_data_id in ^data_ids,
                where: o.sensor == ^value,
                select: o.aot_data_id,
                distinct: o.aot_data_id
              )
          end
      end

    # if observation limited query, apply to data query
    data =
      case obs_data_ids do
        nil -> data
        value -> from d in data, where: d.id in ^value
      end

    # finally apply the windowing `inserted_at` filter
    window =
      case Map.get(conn.params, "inserted_at") do
        nil -> DateTime.utc_now()
        value ->
          [_, term] = String.split(value, ":", parts: 2)
          parse_datetime(term)
      end
    data = from d in data, where: d.inserted_at <= ^window

    # return meta and data queries
    [meta_query: metas, data_query: data]
  end

  def get(conn, _) do
    [meta_query: _, data_query: query] = handle_conn_params(conn)

    pagination = [
      page: Map.get(conn.params, "page", 1),
      page_size: Map.get(conn.params, "page_size", 500)
    ]

    page = Repo.paginate(query, pagination)
    render_page(conn, "get.json", conn.params, page.entries, page, true)
  end

  def head(conn, _) do
    [meta_query: _, data_query: query] = handle_conn_params(conn)

    page = Repo.paginate(query, page: 1, page_size: 1)
    render_page(conn, "get.json", conn.params, page.entries, page, true)
  end

  def describe(conn, _) do
    [meta_query: query, data_query: _] = handle_conn_params(conn)

    pagination = [
      page: Map.get(conn.params, "page", 1),
      page_size: Map.get(conn.params, "page_size", 500)
    ]

    page = Repo.paginate(query, pagination)
    render_page(conn, "get.json", conn.params, page.entries, page, true)
  end
end

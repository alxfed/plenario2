defmodule VirtualPointFieldActionsTests do
  use ExUnit.Case, async: true
  alias Plenario2.Core.Actions.{VirtualPointFieldActions, MetaActions, UserActions}
  alias Plenario2.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    {:ok, user} = UserActions.create("Test User", "password", "test@example.com")
    {:ok, meta} = MetaActions.create("Chicago Tree Trimming", user.id, "https://www.example.com/chicago-tree-trimming")

    [meta: meta]
  end

  test "create virtual point field from long/lat", context do
    {:ok, field} = VirtualPointFieldActions.create_from_long_lat(context.meta.id, "longitude", "latitude")
    assert field.name == "_meta_point_longitude_latitude"
  end

  test "create virutal point field from location", context do
    {:ok, field} = VirtualPointFieldActions.create_from_loc(context.meta.id, "location")
    assert field.name == "_meta_point_location"
  end

  test "list virtual point fields for meta", context do
    VirtualPointFieldActions.create_from_loc(context.meta.id, "location")
    assert length(VirtualPointFieldActions.list_for_meta(context.meta)) == 1
  end

  test "delete virtual point field", context do
    {:ok, field} = VirtualPointFieldActions.create_from_loc(context.meta.id, "location")
    assert length(VirtualPointFieldActions.list_for_meta(context.meta)) == 1

    VirtualPointFieldActions.delete(field)
    assert length(VirtualPointFieldActions.list_for_meta(context.meta)) == 0
  end
end

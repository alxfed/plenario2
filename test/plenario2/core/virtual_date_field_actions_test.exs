defmodule VirtualDateFieldActionsTests do
  use ExUnit.Case, async: true
  alias Plenario2.Core.Actions.{VirtualDateFieldActions, MetaActions, UserActions}
  alias Plenario2.Repo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    {:ok, user} = UserActions.create("Test User", "password", "test@example.com")
    {:ok, meta} = MetaActions.create("Chicago Tree Trimming", user.id, "https://www.example.com/chicago-tree-trimming")

    [meta: meta]
  end

  test "create virtual date field", context do
    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year")
    assert field.name == "_meta_date_year"

    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year", "month")
    assert field.name == "_meta_date_year_month"

    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year", "month", "day")
    assert field.name == "_meta_date_year_month_day"

    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year", "month", "day", "hour")
    assert field.name == "_meta_date_year_month_day_hour"

    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year", "month", "day", "hour", "minute")
    assert field.name == "_meta_date_year_month_day_hour_minute"

    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year", "month", "day", "hour", "minute", "second")
    assert field.name == "_meta_date_year_month_day_hour_minute_second"
  end

  test "list virtual date fields for meta", context do
    VirtualDateFieldActions.create(context.meta.id, "year")
    assert length(VirtualDateFieldActions.list_for_meta(context.meta)) == 1
  end

  test "delete virtual date field", context do
    {:ok, field} = VirtualDateFieldActions.create(context.meta.id, "year")
    assert length(VirtualDateFieldActions.list_for_meta(context.meta)) == 1

    VirtualDateFieldActions.delete(field)
    assert length(VirtualDateFieldActions.list_for_meta(context.meta)) == 0
  end
end

defmodule ExportJobActionsTest do
  use Plenario2.DataCase, async: true

  alias Plenario2.Actions.ExportJobActions

  test "create an export job", context do
    {:ok, job} = ExportJobActions.create(context.meta.id, context.user.id, "select * from chicago_tree_trinning")
    assert job.include_diffs == false
    assert String.match?(job.export_path, ~r{.+/chicago_tree_trimming\..+\.csv})
    assert job.diffs_path == nil
    assert job.export_ttl != nil

    {:ok, job} = ExportJobActions.create(context.meta.id, context.user.id, "select * from chicago_tree_trinning", true)
    assert job.include_diffs == true
    assert String.match?(job.export_path, ~r{.+/chicago_tree_trimming\..+\.csv})
    assert String.match?(job.diffs_path, ~r{.+/chicago_tree_trimming_diffs\..+\.csv})
    assert job.export_ttl != nil
  end

  test "list exports for user", context do
    ExportJobActions.create(context.meta.id, context.user.id, "select * from chicago_tree_trinning")
    ExportJobActions.create(context.meta.id, context.user.id, "select * from chicago_tree_trinning", true)

    assert length(ExportJobActions.list_for_user(context.user)) == 2
  end
end

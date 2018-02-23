defmodule PlenarioEtl.Schemas.ExportJob do
  @moduledoc """
  Defines the schema for ExportJob.

  - `query` is the string version of the query used to generate the output
  - `include_diffs` indicates if the diffs for the data set are requested too
  - `export_path` is the path to the exported file on AWS S3
  - `export_ttl` is the TTL date for the exported file
  - `diffs_path` is the path to the exported diff file on AWS S3
  """

  use Ecto.Schema

  use EctoStateMachine,
    states: [:new, :started, :erred, :completed],
    events: [
      [
        name: :mark_started,
        from: [:new],
        to: :started
      ], [
        name: :mark_erred,
        from: [:started],
        to: :erred
      ], [
        name: :mark_completed,
        from: [:started],
        to: :completed
      ]
    ]

  schema "export_jobs" do
    field(:query, :string)
    field(:include_diffs, :boolean)
    field(:export_path, :string)
    field(:export_ttl, :utc_datetime)
    field(:diffs_path, :string)

    # :inserted_at & :updated_at
    timestamps(type: :utc_datetime)
    field(:state, :string, default: "new")
    field(:error_message, :string)

    belongs_to(:user, Plenario.Schemas.User)
    belongs_to(:meta, Plenario.Schemas.Meta)
  end
end
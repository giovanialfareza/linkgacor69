defmodule LiveMarkdown.Post do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  embedded_schema do
    field :type, Ecto.Enum, values: [:post, :page], default: :post
    field :title, :string
    field :summary, :string
    field :content, :string
    field :slug, :string
    field :date, :utc_datetime
    field :file_path, :string
    field :is_published, :boolean, default: false
    field :metadata, :map
    embeds_many :taxonomies, LiveMarkdown.Link
  end

  def changeset(model, params) do
    model
    |> cast(params, [
      :type,
      :title,
      :summary,
      :content,
      :slug,
      :date,
      :file_path,
      :is_published,
      :metadata
    ])
    |> validate_required([:type, :title, :slug, :date, :file_path])
    |> cast_embed(:taxonomies)
  end
end
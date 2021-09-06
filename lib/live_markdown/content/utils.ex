defmodule LiveMarkdown.Content.Utils do
  def root_path, do: Application.get_env(:live_markdown, LiveMarkdown.Content)[:root_path]

  def static_assets_folder_name,
    do: Application.get_env(:live_markdown, LiveMarkdown.Content)[:static_assets_folder_name]

  def static_assets_path, do: Path.join(root_path(), static_assets_folder_name())

  def is_path_from_static_assets?(path), do: String.starts_with?(path, static_assets_path())

  def remove_root_path(path), do: path |> String.replace(root_path(), "")

  @doc """
  Splits a path into a hierarchy of categories, containing both readable category names
  and slugs for all categories in the hierarchy.

  ## Examples

    iex> LiveMarkdown.Content.Utils.get_categories_from_path("/blog/art/3d-models/post.md")
    [%{category: "Blog", slug: "/blog"}, %{category: "Art", slug: "/blog/art"}, %{category: "3D Models", slug: "/blog/art/3d-models"}]

    iex> LiveMarkdown.Content.Utils.get_categories_from_path("/blog/post.md")
    [%{category: "Blog", slug: "/blog"}]

    iex> LiveMarkdown.Content.Utils.get_categories_from_path("/post.md")
    [%{category: "", slug: "/"}]
  """
  def get_categories_from_path(full_path) do
    full_path
    |> String.replace(Path.basename(full_path), "")
    |> do_extract_categories()
  end

  # Root / Page
  defp do_extract_categories("/"), do: [%{category: "", slug: "/"}]
  # Path with category and possibly, hierarchy
  defp do_extract_categories(path) do
    final_slug = get_slug_from_path(path)
    slug_parts = final_slug |> String.split("/")

    path
    |> String.replace(~r/^\/(.*)\/$/, "\\1")
    |> String.split("/")
    |> Enum.with_index()
    |> Enum.map(fn {part, pos} ->
      slug =
        slug_parts
        |> Enum.take(pos + 2)
        |> Enum.join("/")

      category = part |> get_taxonomy_name()

      %{category: category, slug: slug}
    end)
  end

  @doc """
  ## Examples

    iex> LiveMarkdown.Content.Utils.get_slug_from_path("/blog/art/3d/post.md")
    "/blog/art/3d/post"

    iex> LiveMarkdown.Content.Utils.get_slug_from_path("/blog/My new Project.md")
    "/blog/my-new-project"
  """
  def get_slug_from_path(path) do
    path
    |> String.replace(Path.extname(path), "")
    |> Slug.slugify(ignore: "/")
  end

  @doc """
  Transforms a file name from a path into a readable post title.

  ## Examples

    iex> LiveMarkdown.Content.Utils.get_title_from_path("/blog/art/3d/post-about-art.md")
    "Post about art"

    iex> LiveMarkdown.Content.Utils.get_title_from_path("/blog/My new Project.md")
    "My new Project"
  """
  def get_title_from_path(path) do
    path
    |> Path.basename()
    |> String.replace(Path.extname(path), "")
    |> get_title()
  end

  @doc """
  Transforms a source string into a post or taxonomy title.

  ## Examples

    iex> LiveMarkdown.Content.Utils.get_title("post-about-art")
    "Post about art"

    iex> LiveMarkdown.Content.Utils.get_title("My new Project")
    "My new Project"

    iex> LiveMarkdown.Content.Utils.get_title("2d 3D 4d-art: this is bugged, 3d should've been preserved as 3d not separate strings")
    "2d 3D 4d art: this is bugged, 3d should've been preserved as 3d not separate strings"

    iex> LiveMarkdown.Content.Utils.get_title("Some Startup plans to expand quantum Platform of the Platforms with $500M investment")
    "Some Startup plans to expand quantum Platform of the Platforms with $500M investment"
  """
  def get_title(source) do
    source
    |> prepare_string_for_title()
    |> Enum.with_index()
    |> Enum.map(fn
      {part, 0} ->
        part |> String.capitalize()

      {part, _} ->
        part
    end)
    |> Enum.join(" ")
  end

  def get_taxonomy_name(source) do
    source
    |> prepare_string_for_title()
    |> Enum.map(&String.capitalize/1)
    |> Enum.map(fn part ->
      if String.match?(part, ~r/^[0-9]/) do
        part |> String.upcase()
      else
        part
      end
    end)
    |> Enum.join(" ")
  end

  defp prepare_string_for_title(source) do
    source
    |> String.trim()
    |> String.replace("-", " ")
    |> String.replace("_", " ")
    |> String.split(" ")
  end
end

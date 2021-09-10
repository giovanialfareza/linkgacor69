defmodule LiveMarkdown.Content.Cache do
  require Logger
  alias LiveMarkdown.{Post, Link}
  alias LiveMarkdown.Content.Tree

  @cache_name Application.compile_env!(:live_markdown, [LiveMarkdown.Content, :cache_name])
  @index_cache_name Application.compile_env!(:live_markdown, [
                      LiveMarkdown.Content,
                      :index_cache_name
                    ])

  def get_by_slug(slug), do: ConCache.get(@cache_name, slug_key(slug))

  def get_all_posts(type \\ :all) do
    ConCache.ets(@cache_name)
    |> :ets.tab2list()
    |> Enum.filter(fn
      {_, %Post{type: p_type}} -> type == :all or p_type == type
      _ -> false
    end)
    |> Enum.map(fn {_, %Post{} = post} -> post end)
  end

  def get_all_links(type \\ :all) do
    ConCache.ets(@cache_name)
    |> :ets.tab2list()
    |> Enum.filter(fn
      {_, %Link{type: l_type}} -> type == :all or l_type == type
      _ -> false
    end)
    |> Enum.map(fn {_, %Link{} = link} -> link end)
  end

  def get_taxonomy_tree() do
    get = fn -> ConCache.get(@index_cache_name, taxonomy_tree_key()) end

    case get.() do
      nil ->
        build_taxonomy_tree()
        get.()

      tree ->
        tree
    end
  end

  def get_content_tree(slug \\ "/") do
    get = fn -> ConCache.get(@index_cache_name, content_tree_key(slug)) end

    case get.() do
      nil ->
        build_content_tree(slug)
        get.()

      tree ->
        tree
    end
  end

  def save_post(%Post{type: :index} = post) do
    save_post_taxonomies(post)
  end

  def save_post(%Post{} = post) do
    save_post_pure(post)
    save_post_taxonomies(post)
  end

  def save_post_pure(%Post{type: type, slug: slug} = post) when type != :index do
    key = slug_key(slug)
    :ok = ConCache.put(@cache_name, key, post)
    post
  end

  def update_post_field(slug, field, value) do
    case get_by_slug(slug) do
      nil -> nil
      %Post{} = post -> post |> Map.put(field, value) |> save_post_pure()
    end
  end

  def build_taxonomy_tree() do
    tree = get_all_links() |> Tree.build_taxonomy_tree()
    ConCache.put(@index_cache_name, taxonomy_tree_key(), tree)
    tree
  end

  def build_content_tree(slug \\ "/") do
    tree =
      get_all_links()
      |> Tree.build_content_tree()

    # Update each post in cache with their related link
    # and navigation links
    tree
    |> Tree.get_all_posts_from_tree()
    |> Tree.build_posts_tree_navigation()
    |> Enum.each(fn
      %Post{link: %Link{type: :post, slug: slug} = link} ->
        update_post_field(slug, :link, link)

      _ ->
        :ignore
    end)

    # TODO: Save each node of the content tree independently in the cache, per slug (content_tree_key(slug)). While also keeping the tree.

    ConCache.put(@index_cache_name, content_tree_key(), tree)
    tree
  end

  def delete_slug(slug) do
    ConCache.delete(@cache_name, slug_key(slug))
  end

  def delete_all do
    ConCache.ets(@cache_name)
    |> :ets.delete_all_objects()

    ConCache.ets(@index_cache_name)
    |> :ets.delete_all_objects()
  end

  #
  # Internal
  #

  defp save_post_taxonomies(%Post{type: :index, taxonomies: taxonomies} = post) do
    taxonomies
    |> List.last()
    |> upsert_taxonomy_appending_post(post)
  end

  defp save_post_taxonomies(%Post{taxonomies: taxonomies} = post) do
    taxonomies
    |> Enum.map(&upsert_taxonomy_appending_post(&1, post))
  end

  defp upsert_taxonomy_appending_post(
         %Link{slug: slug} = taxonomy,
         %Post{type: :index, position: position, title: post_title} = post
       ) do
    do_update = fn taxonomy ->
      {:ok,
       %Link{
         taxonomy
         | index_post: post,
           position: position,
           title: post_title
       }}
    end

    ConCache.update(@cache_name, slug_key(slug), fn
      nil ->
        do_update.(taxonomy)

      %Link{} = taxonomy ->
        do_update.(taxonomy)
    end)
  end

  defp upsert_taxonomy_appending_post(
         %Link{slug: slug, children: children} = taxonomy,
         %Post{} = post
       ) do
    do_update = fn taxonomy, children ->
      {:ok, %{taxonomy | children: children ++ [Map.put(post, :content, nil)]}}
    end

    ConCache.update(@cache_name, slug_key(slug), fn
      nil ->
        do_update.(taxonomy, children)

      %Link{children: children} = taxonomy ->
        do_update.(taxonomy, children)
    end)
  end

  defp slug_key(slug), do: {:slug, slug}
  defp taxonomy_tree_key, do: :taxonomy_tree
  defp content_tree_key(slug \\ "/"), do: {:content_tree, slug}
end

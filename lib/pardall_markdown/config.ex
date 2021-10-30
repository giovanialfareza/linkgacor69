defmodule PardallMarkdown.Config do
  def validate_and_get_startup_config! do
    file_interval = Application.get_env(:pardall_markdown, PardallMarkdown.Content)[:recheck_pending_file_events_interval]
    ensure_is_integer!(file_interval, :recheck_pending_file_events_interval)

    repository_url = Application.get_env(:pardall_markdown, PardallMarkdown.Content)[:remote_repository_url]

    if is_binary(repository_url) and repository_url != "" do
      repo_interval = Application.get_env(:pardall_markdown, PardallMarkdown.Content)[:recheck_pending_remote_events_interval]
      ensure_is_integer!(repo_interval, :recheck_pending_remote_events_interval)
      file_interval_first!(repository_url, file_interval, repo_interval)
    end

    %{
      cache_name: Application.get_env(:pardall_markdown, PardallMarkdown.Content)[:cache_name],
      index_cache_name: Application.get_env(:pardall_markdown, PardallMarkdown.Content)[:index_cache_name],
      remote_repository_url: repository_url
    }
  end

  defp ensure_is_integer!(v, _name) when is_number(v) and v > 0, do: v
  defp ensure_is_integer!(_, name), do: raise "Config #{name} is not a valid interval number"

  defp file_interval_first!(repo_url, file, repo)
  when is_binary(repo_url) and repo_url != "" and file < repo, do: :ok
  defp file_interval_first!(_, _, _), do:
    raise "Since :remote_repository_url has been provided, :recheck_pending_file_events_interval must be smaller than :recheck_pending_remote_events_interval"
end

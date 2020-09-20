defmodule Hyades.Github.Mailer do
  use Bamboo.Mailer, otp_app: :hyades
end

defmodule Hyades.Github.Email do
  use Bamboo.Phoenix, view: HyadesWeb.EmailView
  require Logger

  defp base_email() do
    new_email()
    |> from("Hyades<no-reply@hyades.info>")
    |> put_html_layout({HyadesWeb.LayoutView, "email.html"})
  end

  def newsletter(repos, to_whom) do
    Logger.info "Sending newsletter to #{to_whom}"
    base_email()
    |> to(to_whom)
    |> subject("New in your starred repos")
    |> render(:letter, repos: repos)
  end
end
defmodule Hyades.Github.Client.REST do
  require Logger

  defp get_issues(c, repo, since, settings) do
    if settings.show_issues do
      Tentacat.Issues.filter(c, repo["owner"]["login"], repo["name"], %{since: since, per_page: 100})
    else
      {200, [], nil}
    end
  end

  defp get_commits(c, repo, since, settings) do
    if settings.show_commits do
      Tentacat.Commits.filter(c, repo["owner"]["login"], repo["name"], %{since: since, per_page: 100})
    else
      {200, [], nil}
    end
  end

  defp get_releases(c, repo, settings) do
    if settings.show_releases do
      Tentacat.Releases.list(c, repo["owner"]["login"], repo["name"])
    else
      {200, [], nil}
    end
  end

  def get(token, settings) do
    day = 24*3600
    since = DateTime.utc_now() |> DateTime.add(-7*day, :second) |> DateTime.to_iso8601

    c = Tentacat.Client.new(%{access_token: token})

    with {200, starred, _} <- Tentacat.Users.Starring.starred c do
      starred = Enum.sort_by starred, fn s -> s["name"] end
      Enum.map(starred, fn repo ->
        with {200, commits, _} <- get_commits(c, repo, since, settings),
        {200, issues, _} <- get_issues(c, repo, since, settings),
        {200, releases, _} <- get_releases(c, repo, settings) do
          releases = unless is_nil(releases) do
            Enum.filter(releases, fn release ->
              with {:ok, published, _} <- DateTime.from_iso8601(release["published_at"]),
              {:ok, since, _} <- DateTime.from_iso8601(since) do
                Date.compare(published, since) == :gt
              end
            end)
          else
            []
          end
          %{name: repo["name"],
            url: repo["html_url"],
            homepage: repo["homepage"],

            commits: Enum.map(commits, fn c ->
              %{message: c["commit"]["message"],
                url: c["html_url"]}
            end),

            issues: Enum.map(issues, fn issue ->
              %{title: issue["title"],
                url: issue["html_url"],
                body: (if settings.show_issues_body, do: markdown_to_text(issue["body"]), else: ""),
                number: issue["number"],
                labels: Enum.map(issue["labels"], fn l -> %{name: l["name"], color: l["color"]} end)}
            end),

            releases: (Enum.map releases, fn release ->
              %{name: release["name"],
                tag_name: release["tag_name"],
                body: (if settings.show_releases_body, do: markdown_to_text(release["body"]), else: ""),
                url: release["html_url"]}
            end)
          }
        else
          e ->
            Logger.error "while fetching #{repo}: #{inspect e, pretty: true}"
          %{releases: [], issues: [], commits: []}
        end
      end)
      |> Enum.filter(fn r -> not (Enum.empty?(r.releases) and Enum.empty?(r.issues) and Enum.empty?(r.commits)) end)
    end
  end

  defp markdown_to_text(text) when is_nil(text), do: ""
  defp markdown_to_text(text) do
    case Earmark.as_html(text) do
      {:ok, html, _} -> html
      _ -> text
    end
  end
end



defmodule Hyades.Github.Client.GraphQL do
  require Logger

  def get(user, token) do
    with {:ok, %Neuron.Response{body: %{"data" => %{"user" => %{"starredRepositories" => %{"nodes" => repos}}}}, headers: _, status_code: 200}} <- get_repos(user, token) do
      repo = List.first(repos)
      repo_details(Integer.to_string(repo["databaseId"]), token)
    else e -> Logger.error inspect(e, pretty: true)
    end
  end

  defp repo_details(repoID, token) do
    Neuron.Config.set(url: "https://api.github.com/graphql")
    Neuron.Config.set(headers: [authorization: "token #{token}"])
    query = File.read!("queries/repo.gql") |> String.replace("#id#", repoID)
  end

  def get_repos(user, token) do
    Neuron.Config.set(url: "https://api.github.com/graphql")
    Neuron.Config.set(headers: [authorization: "token #{token}"])
    query = File.read!("queries/starred.gql") |> String.replace("#USER#", user)
    Neuron.query(query)
  end

  def get_starred(token) do
    Neuron.Config.set(url: "https://api.github.com/graphql")
    Neuron.Config.set(headers: [authorization: "token #{token}"])

    day = 24*3600
    since = DateTime.utc_now() |> DateTime.add(-7*day, :second) |> DateTime.to_iso8601
    query = File.read!("queries/all.gql")
    # |> String.replace("#USER#", "delehef")
    |> String.replace("#SINCE#", since)
  end
end

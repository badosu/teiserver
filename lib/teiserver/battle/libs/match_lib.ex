defmodule Teiserver.Battle.MatchLib do
  use CentralWeb, :library
  alias Teiserver.Client
  alias Teiserver.Battle.{Match, Lobby}
  alias Teiserver.Data.Types, as: T

  @spec icon :: String.t()
  def icon, do: "far fa-swords"

  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:success2)

  @spec game_type(T.lobby(), map()) :: <<_::24, _::_*8>>
  def game_type(lobby, teams) do
    bot_names = Map.keys(lobby.bots)
      |> Enum.join(" ")

    # It is possible for it to be purely bots v bots which will make it appear to be empty teams
    # this would cause an error with Enum.max, hence the case statement
    max_team_size = case Enum.map(teams, fn {_, team} -> Enum.count(team) end) do
      [] ->
        0
      counts ->
        Enum.max(counts)
    end

    cond do
      String.contains?(bot_names, "Scavenger") -> "Scavengers"
      String.contains?(bot_names, "Chicken") -> "Raptors"
      String.contains?(bot_names, "Raptor") -> "Raptors"
      Enum.empty?(lobby.bots) == false -> "Bots"
      Enum.count(teams) == 2 and max_team_size == 1 -> "Duel"
      Enum.count(teams) == 2 -> "Team"
      max_team_size == 1 -> "FFA"
      true -> "Team FFA"
    end
  end

  def match_from_lobby(lobby_id) do
    lobby = Lobby.get_battle!(lobby_id)

    clients = Client.get_clients(lobby.players)

    teams = clients
    |> Enum.filter(fn c -> c.player == true end)
    |> Enum.group_by(fn c -> c.ally_team_number end)

    game_type = game_type(lobby, teams)

    match = %{
      uuid: lobby.tags["server/match/uuid"],
      map: lobby.map_name,
      data: nil,
      tags: Map.drop(lobby.tags, ["server/match/uuid"]),

      team_count: Enum.count(teams),
      team_size: Enum.max(Enum.map(teams, fn {_, t} -> Enum.count(t) end)),
      passworded: (lobby.password != nil),
      game_type: game_type,

      founder_id: lobby.founder_id,
      bots: lobby.bots,

      started: Timex.now(),
      finished: nil
    }

    members = clients
    |> Enum.filter(fn c -> c.player == true end)
    |> Enum.map(fn client ->
      %{
        user_id: client.userid,
        team_id: client.ally_team_number
      }
    end)

    {match, members}
  end

  @spec stop_match(T.lobby_id()) :: {String.t(), %{finished: DateTime.t()}}
  def stop_match(lobby_id) do
    lobby = Lobby.get_battle!(lobby_id)
    tag = lobby.tags["server/match/uuid"]
    {tag, %{
      finished: Timex.now()
    }}
  end

  def make_match_name(match) do
    case match.game_type do
      "Duel" -> "Duel on #{match.map}"
      "Team" -> "#{match.team_size}v#{match.team_size} on #{match.map}"
      "FFA" -> "#{match.team_count} way FFA on #{match.map}"
      t -> "#{t} game on #{match.map}"
    end
  end

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(match) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: match.id,
      item_type: "teiserver_battle_match",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Battle.MatchLib.icon(),
      item_label: make_match_name(match),

      url: "/battle/matches/#{match.id}"
    }
  end

  # Queries
  @spec query_matches() :: Ecto.Query.t
  def query_matches do
    from matches in Match
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from matches in query,
      where: matches.id == ^id
  end

  def _search(query, :uuid, uuid) do
    from matches in query,
      where: matches.uuid == ^uuid
  end

  def _search(query, :name, name) do
    from matches in query,
      where: matches.name == ^name
  end

  def _search(query, :user_id, user_id) do
    from matches in query,
      join: members in assoc(matches, :members),
      where: members.user_id == ^user_id
  end

  def _search(query, :id_list, id_list) do
    from matches in query,
      where: matches.id in ^id_list
  end

  def _search(query, :ready_for_post_process, _) do
    from matches in query,
      where: matches.processed == false,
      where: not is_nil(matches.finished),
      where: not is_nil(matches.started)
  end

  def _search(query, :processed, value) do
    from matches in query,
      where: matches.processed == ^value
  end

  def _search(query, :of_interest, true) do
    from matches in query,
      where: matches.processed == true,
      where: not is_nil(matches.finished),
      where: not is_nil(matches.started)
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from matches in query,
      where: (
            ilike(matches.name, ^ref_like)
        )
  end

  def _search(query, :never_finished, _) do
    from matches in query,
      where: is_nil(matches.finished)
  end

  def _search(query, :inserted_after, timestamp) do
    from matches in query,
      where: matches.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from matches in query,
      where: matches.inserted_at < ^timestamp
  end

  def _search(query, :started_after, timestamp) do
    from matches in query,
      where: matches.started >= ^timestamp
  end

  def _search(query, :started_before, timestamp) do
    from matches in query,
      where: matches.started < ^timestamp
  end

  def _search(query, :finished_after, timestamp) do
    from matches in query,
      where: matches.finished >= ^timestamp
  end

  def _search(query, :finished_before, timestamp) do
    from matches in query,
      where: matches.finished < ^timestamp
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from matches in query,
      order_by: [asc: matches.name]
  end

  def order_by(query, "Name (Z-A)") do
    from matches in query,
      order_by: [desc: matches.name]
  end

  def order_by(query, "Newest first") do
    from matches in query,
      order_by: [desc: matches.started]
  end

  def order_by(query, "Oldest first") do
    from matches in query,
      order_by: [asc: matches.started]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :members in preloads, do: _preload_members(query), else: query
    query = if :members_and_users in preloads, do: _preload_members_and_users(query), else: query
    query
  end

  def _preload_members(query) do
    from matches in query,
      left_join: members in assoc(matches, :members),
      preload: [members: members]
  end

  def _preload_members_and_users(query) do
    from matches in query,
      left_join: memberships in assoc(matches, :members),
      left_join: users in assoc(memberships, :user),
      # order_by: [asc: memberships.team_id, asc: users.name],
      preload: [members: {memberships, user: users}]
  end
end

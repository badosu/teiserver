alias Teiserver.Repo
alias Central.Helpers.GeneralTestLib

ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(Teiserver.Repo, :manual)

:ok = Ecto.Adapters.SQL.Sandbox.checkout(Teiserver.Repo, sandbox: false)

if not GeneralTestLib.seeded?() do
  GeneralTestLib.seed()
  Teiserver.TeiserverTestLib.seed()
end

Ecto.Adapters.SQL.Sandbox.checkin(Repo)

enabled_startup =
  Application.get_env(:teiserver, Teiserver.SpringTcpServer)
  |> put_in([:listeners, :disable_startup], nil)

Application.put_env(:teiserver, Teiserver.SpringTcpServer, enabled_startup)

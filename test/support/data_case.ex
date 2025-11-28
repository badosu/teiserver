defmodule SupervisorHelper do
  def supervision_tree(supervisor) do
    Enum.reduce(Supervisor.which_children(supervisor), [], fn child_spec, acc ->
      {id, pid, type, modules} = child_spec

      child = [id: id, pid: pid, modules: modules]

      if type == :supervisor do
        [child ++ [supervised: supervision_tree(pid)] | acc]
      else
        [child | acc]
      end
    end)
  end
end

defmodule Teiserver.DataCase do
  @moduledoc """
  This module defines the setup for tests requiring
  access to the application's data layer.

  You may define functions here to be used as helpers in
  your tests.

  Finally, if the test case interacts with the database,
  we enable the SQL sandbox, so changes done to the database
  are reverted at the end of every test. If you are using
  PostgreSQL, you can even run database tests asynchronously
  by setting `use Teiserver.DataCase, async: true`, although
  this option is not recommended for other databases.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Teiserver.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Teiserver.DataCase
    end
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    if tags[:async] do
      repo_pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Teiserver.Repo, shared: not tags[:async])

      Teiserver.TeiserverTestLib.allow_con_caches()
    end

    spring_listeners =
      for transport_type <- [:tcp, :tls] do
        ref = make_ref()

        {:ok, pid} =
          Supervisor.start_child(
            Teiserver.Supervisor,
            Teiserver.Application.spring_server_child(ref, transport_type)
          )

        if tags[:async] do
          :ok = Ecto.Adapters.SQL.Sandbox.allow(Teiserver.Repo, self(), pid)
        end

        {transport_type, [pid: pid, port: :ranch.get_port(ref), ref: ref]}
      end

    dbg([super: SupervisorHelper.supervision_tree(Teiserver.Supervisor)],
      limit: :infinity,
      printable_limit: :infinity,
      pretty: true,
      safe: false
    )

    on_exit(fn ->
      for %{ref: ref} = listener <- spring_listeners do
        result = :ranch.stop_listener(ref)
        # result = DynamicSupervisor.terminate_child(Teiserver.Supervisor, listener_child)
        dbg(killed: {result, listener}, test: tags[:test])
      end

      Ecto.Adapters.SQL.Sandbox.stop_owner(repo_pid)
    end)

    [spring: spring_listeners]
  end

  #
  # defp terminate_listener_connections(listener_pid) do
  #   listener_children = Supervisor.which_children(listener_pid)
  #
  #   con_sup_pids =
  #     for {:ranch_conns_sup, con_sup, _type, _modules} <- listener_children do
  #       Supervisor.which_children(con_sup)
  #       |> Enum.map(&{con_sup, elem(&1, 1)})
  #     end
  #     |> List.flatten()
  #
  #   for {con_sup, conn_pid} <- con_sup_pids do
  #     :ok = Supervisor.terminate_child(con_sup, conn_pid)
  #   end
  # end

  # defp allow_server_listeners() do
  #   for {{:ranch_listener_sup, ref}, pid, _type, _modules}
  #       when ref in [Teiserver.SSLSpringTcpServer, Teiserver.TCPSpringTcpServer] <-
  #         Supervisor.which_children(Teiserver.Supervisor) do
  #     allow_result = Ecto.Adapters.SQL.Sandbox.allow(Teiserver.Repo, self(), pid)
  #     dbg(allow_result: {allow_result, ref})
  #
  #     pid
  #   end
  # end

  setup tags do
    opts = setup_sandbox(tags)
    Teiserver.Support.Tachyon.tachyon_case_setup(tags)
    {:ok, opts}
  end
end

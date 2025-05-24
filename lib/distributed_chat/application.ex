defmodule DistributedChat.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      # Iniciar el administrador de usuarios y salas
      DistributedChat.UserManager,
      # Iniciar el GenServer para manejar mensajes entre nodos
      DistributedChat.CLI
      # Quitamos la tarea para iniciar la CLI desde aquí
    ]

    # Iniciar la interfaz de consola manualmente después de que el supervisor esté listo
    Task.start(fn ->
      # Esperar a que todo esté listo
      Process.sleep(500)
      DistributedChat.CLI.start()
    end)

    opts = [strategy: :one_for_one, name: DistributedChat.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

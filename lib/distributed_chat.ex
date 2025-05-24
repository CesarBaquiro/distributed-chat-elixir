defmodule DistributedChat.CLI do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start do
    # Iniciar la consola mejorada
    DistributedChat.Console.start()
  end

  @impl true
  def init(_) do
    state = %{
      users: %{},
      rooms: %{"general" => %{name: "general", users: [], created_at: DateTime.utc_now()}},
      user_count: 0
    }

    {:ok, state}
  end

  @impl true
  def handle_info({:message, message}, state) do
    IO.puts(message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:room_message, room_name, message}, state) do
    # Mostrar siempre el mensaje (la verificación de sala se hace al enviar)
    IO.puts(message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:system_message, message}, state) do
    IO.puts(message)
    {:noreply, state}
  end

  @impl true
  def handle_info({:user_notification, message}, state) do
    IO.puts("[NOTIFICACIÓN] #{message}")
    {:noreply, state}
  end
end

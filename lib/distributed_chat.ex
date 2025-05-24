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
    user_id = Process.get(:user_id)

    # Mostrar siempre mensajes de la sala general
    # y mensajes de otras salas solo si el usuario está en ellas
    if room_name == "general" do
      IO.puts(message)
    else
      if user_id do
        case DistributedChat.UserManager.get_user_room(user_id) do
          {:ok, ^room_name} -> IO.puts(message)
          _ -> :ok
        end
      end
    end

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

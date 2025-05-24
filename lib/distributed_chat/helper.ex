defmodule DistributedChat.Helper do
  def connect_to(node_name) do
    node_atom = if is_atom(node_name), do: node_name, else: String.to_atom(node_name)

    case Node.connect(node_atom) do
      true ->
        IO.puts("Conectado con éxito a #{node_atom}")
        # Sincronizar usuarios y salas (incluyendo 'general')
        DistributedChat.UserManager.sync_with_nodes()
        true

      false ->
        IO.puts("No se pudo conectar a #{node_atom}")
        false
    end
  end

  def register_user(username) do
    case DistributedChat.UserManager.register_user(username) do
      {:ok, user_id} ->
        Process.put(:user_id, user_id)
        Process.put(:username, username)
        IO.puts("Usuario registrado con ID: #{user_id}")
        user_id

      {:error, reason} ->
        IO.puts("Error al registrar usuario: #{reason}")
        nil
    end
  end

  def send_message(message) do
    user_id = Process.get(:user_id)
    username = Process.get(:username) || "anónimo"

    if user_id do
      case DistributedChat.UserManager.get_user_room(user_id) do
        {:ok, room_name} ->
          formatted = "[#{room_name}] #{username}: #{message}"
          IO.puts(formatted)

          # Enviar a TODOS los usuarios de la sala (incluido otros nodos)
          case DistributedChat.UserManager.get_room_users(room_name) do
            {:ok, room_users} ->
              Enum.each(room_users, fn user ->
                if user.node != Node.self() do
                  send({DistributedChat.CLI, user.node}, {:room_message, room_name, formatted})
                end
              end)

            {:error, reason} ->
              IO.puts("Error al obtener usuarios de la sala: #{reason}")
          end

        {:error, reason} ->
          IO.puts("Error: #{reason}")
      end
    else
      IO.puts("Error: Debes registrarte primero con /register NOMBRE")
    end
  end

  def set_username(username) do
    old_name = Process.get(:username) || "anónimo"

    # Primero desregistrar el usuario anterior si existe
    if user_id = Process.get(:user_id) do
      DistributedChat.UserManager.unregister_user(user_id)
    end

    # Registrar con el nuevo nombre
    case register_user(username) do
      nil ->
        IO.puts("Error al cambiar nombre de usuario")

      _user_id ->
        IO.puts("Nombre de usuario cambiado de '#{old_name}' a '#{username}'")
        broadcast_system_message("#{old_name} ha cambiado su nombre a #{username}")
    end
  end

  def list_nodes do
    nodes = Node.list()

    if Enum.empty?(nodes) do
      IO.puts("No hay nodos conectados")
    else
      IO.puts("Nodos conectados (#{length(nodes)}):")
      Enum.each(nodes, fn node -> IO.puts("  - #{node}") end)
    end
  end

  def list_users do
    users = DistributedChat.UserManager.list_users()

    if Enum.empty?(users) do
      IO.puts("No hay usuarios conectados")
    else
      IO.puts("Usuarios conectados (#{length(users)}):")

      Enum.each(users, fn user ->
        status_icon = if user.status == :online, do: "🟢", else: "🔴"

        IO.puts(
          "  #{status_icon} #{user.username} (#{user.id}) - Sala: #{user.current_room} - Nodo: #{user.node}"
        )
      end)
    end
  end

  def list_rooms do
    rooms = DistributedChat.UserManager.list_rooms()

    if Enum.empty?(rooms) do
      IO.puts("No hay salas disponibles")
    else
      IO.puts("Salas disponibles (#{length(rooms)}):")

      Enum.each(rooms, fn room ->
        user_list = Enum.join(room.users, ", ")
        IO.puts("  📝 #{room.name} (#{room.user_count} usuarios)")

        if room.user_count > 0 do
          IO.puts("     Usuarios: #{user_list}")
        end
      end)
    end
  end

  def create_room(room_name) do
    user_id = Process.get(:user_id)

    if user_id do
      case DistributedChat.UserManager.create_room(room_name, user_id) do
        {:ok, ^room_name} ->
          IO.puts("Sala '#{room_name}' creada exitosamente")
          # El broadcast ahora lo hace UserManager directamente
          true

        {:error, :room_exists} ->
          IO.puts("Error: La sala '#{room_name}' ya existe")
          false

        {:error, reason} ->
          IO.puts("Error al crear sala: #{reason}")
          false
      end
    else
      IO.puts("Error: Debes registrarte primero con /register NOMBRE")
      false
    end
  end

  def join_room(room_name) do
    user_id = Process.get(:user_id)
    username = Process.get(:username)

    if user_id do
      case DistributedChat.UserManager.join_room(room_name, user_id) do
        {:ok, ^room_name} ->
          IO.puts("Te has unido a la sala '#{room_name}'")
          broadcast_room_message(room_name, "#{username} se ha unido a la sala")

        {:error, :room_not_found} ->
          IO.puts("Error: La sala '#{room_name}' no existe")

        {:error, reason} ->
          IO.puts("Error al unirse a la sala: #{reason}")
      end
    else
      IO.puts("Error: Debes registrarte primero con /register NOMBRE")
    end
  end

  def leave_room do
    user_id = Process.get(:user_id)
    username = Process.get(:username)

    if user_id do
      case DistributedChat.UserManager.get_user_room(user_id) do
        {:ok, current_room} ->
          case DistributedChat.UserManager.leave_room(user_id) do
            {:ok, "general"} ->
              IO.puts("Has salido de '#{current_room}' y regresado a la sala general")
              broadcast_room_message(current_room, "#{username} ha salido de la sala")

            {:error, reason} ->
              IO.puts("Error al salir de la sala: #{reason}")
          end

        _ ->
          IO.puts("Error: No estás en ninguna sala")
      end
    else
      IO.puts("Error: Debes registrarte primero con /register NOMBRE")
    end
  end

  def get_current_room do
    user_id = Process.get(:user_id)

    if user_id do
      case DistributedChat.UserManager.get_user_room(user_id) do
        {:ok, room_name} ->
          IO.puts("Estás actualmente en la sala: #{room_name}")

        _ ->
          IO.puts("Error: No estás en ninguna sala")
      end
    else
      IO.puts("Error: Debes registrarte primero")
    end
  end

  # Funciones privadas para broadcasts
  defp broadcast_system_message(message) do
    formatted = "[SISTEMA] #{message}"
    IO.puts(formatted)

    # Enviar a todos los nodos conectados
    Enum.each(Node.list(), fn node ->
      send({DistributedChat.CLI, node}, {:system_message, formatted})
    end)
  end

  defp broadcast_room_message(room_name, message) do
    formatted = "[#{room_name}] [SISTEMA] #{message}"
    IO.puts(formatted)

    case DistributedChat.UserManager.get_room_users(room_name) do
      {:ok, users} ->
        Enum.each(users, fn user ->
          if user.node != Node.self() do
            send({DistributedChat.CLI, user.node}, {:room_message, room_name, formatted})
          end
        end)

      _ ->
        :ok
    end
  end
end

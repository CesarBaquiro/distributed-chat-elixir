defmodule DistributedChat.UserManager do
  use GenServer

  @doc """
  Estructura para un usuario
  """
  defstruct [:id, :username, :node, :current_room, :status, :joined_at]

  def start_link(_) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  @impl true
  def init(_) do
    # Estado inicial: usuarios conectados y salas disponibles
    state = %{
      users: %{},
      rooms: %{"general" => %{name: "general", users: [], created_at: DateTime.utc_now()}},
      user_count: 0
    }

    {:ok, state}
  end

  # API Pública

  def register_user(username) do
    GenServer.call(__MODULE__, {:register_user, username, Node.self()})
  end

  def unregister_user(user_id) do
    GenServer.call(__MODULE__, {:unregister_user, user_id})
  end

  def list_users do
    GenServer.call(__MODULE__, :list_users)
  end

  def list_rooms do
    GenServer.call(__MODULE__, :list_rooms)
  end

  def create_room(room_name, user_id) do
    GenServer.call(__MODULE__, {:create_room, room_name, user_id})
  end

  def join_room(room_name, user_id) do
    GenServer.call(__MODULE__, {:join_room, room_name, user_id})
  end

  def leave_room(user_id) do
    GenServer.call(__MODULE__, {:leave_room, user_id})
  end

  def get_user_room(user_id) do
    GenServer.call(__MODULE__, {:get_user_room, user_id})
  end

  def get_room_users(room_name) do
    GenServer.call(__MODULE__, {:get_room_users, room_name})
  end

  def sync_with_nodes do
    GenServer.cast(__MODULE__, :sync_with_nodes)
  end

  # Callbacks del GenServer

  @impl true
  def handle_call({:register_user, username, node}, _from, state) do
    user_id = generate_user_id(state.user_count)

    user = %__MODULE__{
      id: user_id,
      username: username,
      node: node,
      current_room: "general",
      status: :online,
      joined_at: DateTime.utc_now()
    }

    # Agregar usuario al estado
    new_users = Map.put(state.users, user_id, user)

    # Agregar usuario a la sala general
    general_room = state.rooms["general"]
    updated_general = %{general_room | users: [user_id | general_room.users]}
    new_rooms = Map.put(state.rooms, "general", updated_general)

    new_state = %{state | users: new_users, rooms: new_rooms, user_count: state.user_count + 1}

    # Notificar a otros nodos
    broadcast_user_update({:user_joined, user})

    {:reply, {:ok, user_id}, new_state}
  end

  @impl true
  def handle_call({:unregister_user, user_id}, _from, state) do
    case Map.get(state.users, user_id) do
      nil ->
        {:reply, {:error, :user_not_found}, state}

      user ->
        # Remover de la sala actual
        current_room = state.rooms[user.current_room]
        updated_room = %{current_room | users: List.delete(current_room.users, user_id)}
        new_rooms = Map.put(state.rooms, user.current_room, updated_room)

        # Remover usuario
        new_users = Map.delete(state.users, user_id)
        new_state = %{state | users: new_users, rooms: new_rooms}

        # Notificar a otros nodos
        broadcast_user_update({:user_left, user})

        {:reply, :ok, new_state}
    end
  end

  @impl true
  def handle_call(:list_users, _from, state) do
    users_list =
      Enum.map(state.users, fn {_id, user} ->
        %{
          id: user.id,
          username: user.username,
          node: user.node,
          current_room: user.current_room,
          status: user.status,
          joined_at: user.joined_at
        }
      end)

    {:reply, users_list, state}
  end

  @impl true
  def handle_call(:list_rooms, _from, state) do
    rooms_list =
      Enum.map(state.rooms, fn {_name, room} ->
        %{
          name: room.name,
          user_count: length(room.users),
          users:
            Enum.map(room.users, fn user_id ->
              state.users[user_id].username
            end),
          created_at: room.created_at
        }
      end)

    {:reply, rooms_list, state}
  end

  @impl true
  def handle_call({:create_room, room_name, user_id}, _from, state) do
    if Map.has_key?(state.rooms, room_name) do
      {:reply, {:error, :room_exists}, state}
    else
      new_room = %{
        name: room_name,
        users: [],
        created_at: DateTime.utc_now()
      }

      new_rooms = Map.put(state.rooms, room_name, new_room)
      new_state = %{state | rooms: new_rooms}

      # Notificar a TODOS los nodos (incluyendo al actual)
      Enum.each([Node.self() | Node.list()], fn node ->
        send({__MODULE__, node}, {:room_created, room_name, user_id, new_room})
      end)

      {:reply, {:ok, room_name}, new_state}
    end
  end

  @impl true
  def handle_call({:join_room, room_name, user_id}, _from, state) do
    case {Map.get(state.users, user_id), Map.get(state.rooms, room_name)} do
      {nil, _} ->
        {:reply, {:error, :user_not_found}, state}

      {_, nil} ->
        {:reply, {:error, :room_not_found}, state}

      {user, target_room} ->
        # Remover de sala actual
        current_room = state.rooms[user.current_room]
        updated_current = %{current_room | users: List.delete(current_room.users, user_id)}

        # Agregar a nueva sala
        updated_target = %{target_room | users: [user_id | target_room.users]}

        # Actualizar usuario
        updated_user = %{user | current_room: room_name}

        new_rooms =
          state.rooms
          |> Map.put(user.current_room, updated_current)
          |> Map.put(room_name, updated_target)

        new_users = Map.put(state.users, user_id, updated_user)
        new_state = %{state | users: new_users, rooms: new_rooms}

        # Notificar a TODOS los nodos para actualizar el estado
        broadcast_user_update({:user_changed_room, updated_user, user.current_room, room_name})

        {:reply, {:ok, room_name}, new_state}
    end
  end

  @impl true
  def handle_info({:user_changed_room, user, old_room, new_room}, state) do
    # Actualizar el estado local para reflejar el cambio en el nodo remoto
    case Map.get(state.users, user.id) do
      nil ->
        # Usuario no existe localmente, ignorar
        {:noreply, state}

      local_user ->
        # Solo actualizar si el usuario estaba en la sala antigua
        if local_user.current_room == old_room do
          # Actualizar sala actual del usuario
          updated_user = %{local_user | current_room: new_room}
          new_users = Map.put(state.users, user.id, updated_user)

          # Mover usuario entre salas localmente
          old_room_users = state.rooms[old_room].users -- [user.id]
          new_room_users = [user.id | state.rooms[new_room].users]

          new_rooms =
            state.rooms
            |> Map.put(old_room, %{state.rooms[old_room] | users: old_room_users})
            |> Map.put(new_room, %{state.rooms[new_room] | users: new_room_users})

          new_state = %{state | users: new_users, rooms: new_rooms}

          # Mostrar notificación
          IO.puts("[SISTEMA] #{user.username} se movió a '#{new_room}'")
          {:noreply, new_state}
        else
          {:noreply, state}
        end
    end
  end

  defp notify_room_change(user, old_room, new_room, state) do
    # Obtener usuarios directamente del estado
    old_users = get_room_users_from_state(old_room, state)
    new_users = get_room_users_from_state(new_room, state)

    # Notificar a sala antigua
    Enum.each(old_users, fn u ->
      if u.id != user.id do
        send(
          {DistributedChat.CLI, u.node},
          {:room_message, old_room, "[SISTEMA] #{user.username} salió de la sala"}
        )
      end
    end)

    # Notificar a sala nueva
    Enum.each(new_users, fn u ->
      if u.id != user.id do
        send(
          {DistributedChat.CLI, u.node},
          {:room_message, new_room, "[SISTEMA] #{user.username} entró a la sala"}
        )
      end
    end)
  end

  defp get_room_users_from_state(room_name, %{users: users, rooms: rooms}) do
    case Map.get(rooms, room_name) do
      nil -> []
      room -> Enum.map(room.users, &Map.get(users, &1))
    end
  end

  @impl true
  def handle_call({:leave_room, user_id}, _from, state) do
    # Por defecto, volver a la sala general
    handle_call({:join_room, "general", user_id}, nil, state)
  end

  @impl true
  def handle_call({:get_user_room, user_id}, _from, state) do
    case Map.get(state.users, user_id) do
      nil -> {:reply, {:error, :user_not_found}, state}
      user -> {:reply, {:ok, user.current_room}, state}
    end
  end

  @impl true
  def handle_call({:get_room_users, room_name}, _from, state) do
    case Map.get(state.rooms, room_name) do
      nil ->
        {:reply, {:error, :room_not_found}, state}

      room ->
        users = Enum.map(room.users, fn user_id -> state.users[user_id] end)
        {:reply, {:ok, users}, state}
    end
  end

  @impl true
  def handle_cast(:sync_with_nodes, state) do
    # Sincronizar estado con otros nodos
    Enum.each(Node.list(), fn node ->
      send({__MODULE__, node}, {:sync_state, state})
    end)

    {:noreply, state}
  end

  @impl true
  def handle_info({:sync_state, remote_state}, local_state) do
    merged_users = merge_users(local_state.users, remote_state.users)
    merged_rooms = merge_rooms(local_state.rooms, remote_state.rooms)

    new_state = %{
      local_state
      | users: merged_users,
        rooms: merged_rooms,
        user_count: map_size(merged_users)
    }

    {:noreply, new_state}
  end

  @impl true
  def handle_info({:user_joined, user}, state) do
    IO.puts("[SISTEMA] #{user.username} (#{user.id}) se ha conectado desde #{user.node}")
    {:noreply, state}
  end

  @impl true
  def handle_info({:user_left_room, user, room_name}, state) do
    IO.puts("[SISTEMA] #{user.username} salió de '#{room_name}'")
    {:noreply, state}
  end

  @impl true
  def handle_info({:user_joined_room, user, room_name}, state) do
    IO.puts("[SISTEMA] #{user.username} entró a '#{room_name}'")
    {:noreply, state}
  end

  @impl true
  def handle_info({:room_created, room_name, _user_id, new_room}, state) do
    if !Map.has_key?(state.rooms, room_name) do
      new_rooms = Map.put(state.rooms, room_name, new_room)
      {:noreply, %{state | rooms: new_rooms}}
    else
      {:noreply, state}
    end
  end

  # Funciones privadas

  defp generate_user_id(count) do
    "user_#{count + 1}_#{:rand.uniform(9999)}"
  end

  defp broadcast_user_update(message) do
    Enum.each(Node.list(), fn node ->
      send({__MODULE__, node}, message)
    end)
  end

  defp broadcast_room_update(message) do
    Enum.each(Node.list(), fn node ->
      send({__MODULE__, node}, message)
    end)
  end

  # API pública
  def sync_with_node(node) do
    GenServer.cast(__MODULE__, {:sync_with_node, node})
  end

  # Callback para manejar la sincronización con un nodo específico
  @impl true
  def handle_cast({:sync_with_node, node}, state) do
    # Enviar nuestro estado al nodo remoto
    send({__MODULE__, node}, {:sync_state, state})
    # Solicitar el estado del nodo remoto
    send({__MODULE__, node}, {:request_state, Node.self()})
    {:noreply, state}
  end

  # Callback para manejar la solicitud de estado
  @impl true
  def handle_info({:request_state, from_node}, state) do
    # Responder con nuestro estado al nodo solicitante
    send({__MODULE__, from_node}, {:sync_state, state})
    {:noreply, state}
  end

  # Callback para fusionar el estado remoto con el local
  @impl true
  def handle_info({:sync_state, remote_state}, local_state) do
    # Fusionar usuarios (evitando duplicados)
    merged_users = Map.merge(local_state.users, remote_state.users)
    # Fusionar salas (ejemplo básico)
    merged_rooms = Map.merge(local_state.rooms, remote_state.rooms)
    # Actualizar estado
    new_state = %{local_state | users: merged_users, rooms: merged_rooms}
    {:noreply, new_state}
  end

  defp merge_users(local_users, remote_users) do
    Map.merge(local_users, remote_users, fn _id, local_user, remote_user ->
      # Prefiere el usuario local si existe, de lo contrario usa el remoto
      # Puedes personalizar esta lógica según tus necesidades
      if Map.has_key?(local_users, local_user.id) do
        local_user
      else
        remote_user
      end
    end)
  end

  defp merge_rooms(local_rooms, remote_rooms) do
    Map.merge(local_rooms, remote_rooms, fn _name, local_room, remote_room ->
      # Fusiona las listas de usuarios de las salas, eliminando duplicados
      merged_users = (local_room.users ++ remote_room.users) |> Enum.uniq()

      %{
        name: local_room.name,
        users: merged_users,
        created_at: earliest_creation(local_room.created_at, remote_room.created_at)
      }
    end)
  end

  defp earliest_creation(dt1, dt2) do
    case DateTime.compare(dt1, dt2) do
      :lt -> dt1
      _ -> dt2
    end
  end
end

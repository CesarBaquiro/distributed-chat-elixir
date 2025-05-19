defmodule DistributedChat.Helper do
  def connect_to(node_name) do
    node_atom = if is_atom(node_name), do: node_name, else: String.to_atom(node_name)

    case Node.connect(node_atom) do
      true -> IO.puts("Conectado con éxito a #{node_atom}")
      false -> IO.puts("No se pudo conectar a #{node_atom}")
    end
  end

  def send_message(message) do
    username = Process.get(:username) || "anónimo"
    formatted = "#{username}: #{message}"

    # Mostrar localmente
    IO.puts(formatted)

    # Enviar a todos los nodos conectados
    Enum.each(Node.list(), fn node ->
      send({DistributedChat.CLI, node}, {:message, formatted})
    end)
  end

  def set_username(username) do
    Process.put(:username, username)
    IO.puts("Nombre de usuario establecido a: #{username}")
  end

  def list_nodes do
    IO.puts("Nodos conectados: #{inspect(Node.list())}")
  end
end

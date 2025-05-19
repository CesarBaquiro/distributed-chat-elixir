defmodule DistributedChat.CLI do
  use GenServer

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def start do
    # Configurar nombre del nodo si no está configurado
    unless Node.alive?() do
      {username, _} = System.cmd("whoami", [])
      username = String.trim(username)
      Node.start(:"chat_#{username}@127.0.0.1")
      Node.set_cookie(:distributed_chat_cookie)
    end

    IO.puts("Chat iniciado como #{Node.self()}")
    IO.puts("Escribe ':connect nombre@host' para conectarte a otro nodo")
    IO.puts("Escribe ':nodes' para ver los nodos conectados")
    IO.puts("Escribe ':name TU_NOMBRE' para establecer tu nombre de usuario")
    IO.puts("Escribe ':exit' para salir")
    IO.puts("Escribe cualquier otro texto para enviar un mensaje")

    # Establecer nombre de usuario por defecto
    username = "usuario_#{:rand.uniform(1000)}"
    Process.put(:username, username)
    IO.puts("Tu nombre de usuario por defecto es: #{username}")

    listen_loop()
  end

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_info({:message, message}, state) do
    IO.puts(message)
    {:noreply, state}
  end

  defp listen_loop do
    input = IO.gets("> ")

    case String.trim(input) do
      ":exit" ->
        IO.puts("¡Adiós!")
        System.halt(0)

      ":nodes" ->
        IO.puts("Nodos conectados: #{inspect(Node.list())}")
        listen_loop()

      ":name " <> new_name ->
        new_name = String.trim(new_name)
        Process.put(:username, new_name)
        IO.puts("Tu nombre de usuario ha sido cambiado a: #{new_name}")
        listen_loop()

      ":connect " <> node ->
        node = String.to_atom(String.trim(node))

        case Node.connect(node) do
          true ->
            IO.puts("Conectado con éxito a #{node}")
            send_message_to_all("se ha unido al chat")

          false ->
            IO.puts("No se pudo conectar a #{node}")
        end

        listen_loop()

      message ->
        send_message_to_all(message)
        listen_loop()
    end
  end

  def send_message_to_all(message) do
    username = Process.get(:username)
    formatted = "#{username}: #{message}"

    # Mostrar localmente
    IO.puts(formatted)

    # Enviar a todos los nodos conectados
    Enum.each(Node.list(), fn node ->
      send({__MODULE__, node}, {:message, formatted})
    end)
  end
end

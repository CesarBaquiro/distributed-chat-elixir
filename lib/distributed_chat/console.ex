defmodule DistributedChat.Console do
  @moduledoc """
  Una interfaz de consola avanzada para el chat distribuido con salas y usuarios.
  """

  @doc """
  Inicia la interfaz de consola interactiva.
  """
  def start do
    # Mostrar mensaje de bienvenida
    IO.puts("\n=== Chat Distribuido en Elixir ===")
    IO.puts("Nodo actual: #{Node.self()}")
    IO.puts("\n¡Bienvenido! Primero debes registrarte con un nombre de usuario.")
    IO.puts("Escribe: /register TU_NOMBRE")
    IO.puts("\nComandos disponibles:")
    show_help()
    IO.puts("------------------------------------------------")

    # Iniciar el bucle de la consola
    console_loop()
  end

  defp console_loop do
    input = IO.gets("> ")
    input = String.trim(input)

    cond do
      input == "/exit" ->
        # Desregistrar usuario antes de salir
        if user_id = Process.get(:user_id) do
          DistributedChat.UserManager.unregister_user(user_id)
        end

        IO.puts("¡Adiós!")

      input == "/help" ->
        show_help()
        console_loop()

      input == "/nodes" ->
        DistributedChat.Helper.list_nodes()
        console_loop()

      input == "/users" ->
        DistributedChat.Helper.list_users()
        console_loop()

      input == "/rooms" ->
        DistributedChat.Helper.list_rooms()
        console_loop()

      input == "/room" ->
        DistributedChat.Helper.get_current_room()
        console_loop()

      input == "/leave" ->
        DistributedChat.Helper.leave_room()
        console_loop()

      String.starts_with?(input, "/register ") ->
        username = String.trim_leading(input, "/register ")
        DistributedChat.Helper.register_user(username)
        console_loop()

      String.starts_with?(input, "/name ") ->
        new_name = String.trim_leading(input, "/name ")
        DistributedChat.Helper.set_username(new_name)
        console_loop()

      String.starts_with?(input, "/connect ") ->
        node_name = String.trim_leading(input, "/connect ")
        node_atom = String.to_atom(node_name)
        DistributedChat.Helper.connect_to(node_atom)
        console_loop()

      String.starts_with?(input, "/create ") ->
        room_name = String.trim_leading(input, "/create ")
        DistributedChat.Helper.create_room(room_name)
        console_loop()

      String.starts_with?(input, "/join ") ->
        room_name = String.trim_leading(input, "/join ")
        DistributedChat.Helper.join_room(room_name)
        console_loop()

      true ->
        # Cualquier otro texto es un mensaje
        if Process.get(:user_id) do
          DistributedChat.Helper.send_message(input)
        else
          IO.puts("Debes registrarte primero con: /register TU_NOMBRE")
        end

        console_loop()
    end
  end

  defp show_help do
    IO.puts("\n=== Comandos de Usuario ===")
    IO.puts("  /register NOMBRE     - Registrarte con un nombre de usuario")
    IO.puts("  /name NOMBRE         - Cambiar tu nombre de usuario")
    IO.puts("  /users               - Mostrar usuarios conectados")
    IO.puts("")
    IO.puts("=== Comandos de Conexión ===")
    IO.puts("  /connect NODO        - Conectarse a otro nodo (ej: /connect nodo2@127.0.0.1)")
    IO.puts("  /nodes               - Mostrar nodos conectados")
    IO.puts("")
    IO.puts("=== Comandos de Salas ===")
    IO.puts("  /rooms               - Mostrar todas las salas disponibles")
    IO.puts("  /room                - Mostrar tu sala actual")
    IO.puts("  /create NOMBRE       - Crear una nueva sala")
    IO.puts("  /join NOMBRE         - Unirse a una sala existente")
    IO.puts("  /leave               - Salir de la sala actual (volver a 'general')")
    IO.puts("")
    IO.puts("=== Comandos Generales ===")
    IO.puts("  /help                - Mostrar esta ayuda")
    IO.puts("  /exit                - Salir del chat")
    IO.puts("\n💬 Escribe cualquier otro texto para enviar un mensaje a tu sala actual")
  end
end

# DistributedChat

**El chat distribuido es un sistema de manesajeria cliente - servidor el cual permite la comunicacion entre diferentes nodos en maquinas separadas**

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `distributed_chat` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:distributed_chat, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/distributed_chat>.

## Uso

Iniciar el nodo 1

```
iex.bat --name nodo1@127.0.0.1 -S mix
```

Iniciar el nodo 2

```
iex.bat --name nodo2@127.0.0.1 -S mix
```

Conectarse del nodo 1 al nodo 2

```
DistributedChat.Helper.connect_to(:"nodo2@127.0.0.1")
```

Conectarse del nodo 2 al nodo 1

```
DistributedChat.Helper.connect_to(:"nodo1@127.0.0.1")
```

Establecer nombres de usuario

```
DistributedChat.Helper.set_username("Nombre del usuario")
```

Enviar mensajes

```
DistributedChat.Helper.send_message("Hola desde nodo x ")
```

---

Otros comandos

Listar todos los nodos

```
DistributedChat.Helper.list_nodes()
```

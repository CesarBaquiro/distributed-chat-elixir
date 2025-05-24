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

Iniciar la consola

```
DistributedChat.Console.start()
```

Establecer nombres de usuario

```
/register <Nombre del usuario>
```

Conectarse del nodo 1 al nodo 2

```
/connect nodo2@127.0.0.1
```

Conectarse del nodo 2 al nodo 1

```
/connect nodo1@127.0.0.1
```

Enviar mensajes por la consola

```
<Mensaje a enviar>
```

---

### Otros comandos

Listar todos los nodos

```
/nodes
```

Listar todos los usuarios

```
/users
```

Listar todas las salas

```
/rooms
```

Saber en que sala esta

```
/room
```

Crear una sala

```
/create <Nombre de la sala>
```

Entrar a una sala

```
/join <Nombre de la sala>
```

defmodule Deejay.Port.State do
  defstruct [:port, :socket, :tcp_opts]
end

defmodule Deejay.Port.InitOptions do
  defstruct binary: true,
            packet: :raw,
            active: false,
            ip: nil,
            reuseaddr: true,
            nodelay: false

  def to_list(opts) do
    []
    |> then(fn list -> if opts.binary, do: [:binary | list], else: list end)
    |> then(&[{:packet, opts.packet} | &1])
    |> then(&[{:active, opts.active} | &1])
    |> then(&[{:reuseaddr, opts.reuseaddr} | &1])
    |> then(&[{:nodelay, opts.nodelay} | &1])
    |> Enum.reverse()
  end
end

defmodule Deejay.Port do
  use GenServer

  def begin_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  @impl true
  def init(opts) do
    port = Keyword.get(opts, :port, 4050)
    tcp_opts = Keyword.get(opts, :tcp_opts, %Deejay.Port.InitOptions{})

    send(self(), :init)

    {:ok,
     %Deejay.Port.State{
       port: port,
       tcp_opts: tcp_opts
     }}
  end

  def handle_client(client) do
    case :gen_tcp.recv(client, 0) do
      {:ok, data} ->
        response =
          case Deejay.Parser.parse_request(data) do
            {:ok, request} ->
              request
              |> Deejay.Router.route()
              |> Deejay.Http.Response.serialize()

            {:error, _reason} ->
              %Deejay.Http.Response{
                status: 400,
                headers: %{
                  "Content-Type" => "text/plain"
                },
                body: "Bad Request"
              }
              |> Deejay.Http.Response.serialize()
          end

        :gen_tcp.send(client, response)

      {:error, _} ->
        :ok
    end

    :gen_tcp.close(client)
  end

  @impl true
  def handle_info(:accept, state) do
    {:ok, client} = :gen_tcp.accept(state.socket)

    send(self(), :accept)

    spawn(&handle_client(client))

    {:noreply, state}
  end

  @impl true
  def handle_info(:init, state) do
    {:ok, socket} =
      :gen_tcp.listen(
        state.port,
        Deejay.Port.InitOptions.to_list(state.tcp_opts)
      )

    send(self(), :accept)

    {:noreply, %{state | socket: socket}}
  end
end

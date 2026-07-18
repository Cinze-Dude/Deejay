defmodule Deejay.Http.Request do
  defstruct [
    :command,
    :path,
    :query,
    :version,
    :headers,
    :body
  ]
end

defmodule Deejay.Http.Response do
  defstruct [
    :status,
    :headers,
    :body
  ]

  def serialize(%Deejay.Http.Response{status: status, headers: headers, body: body}) do
    fstat =
      case status do
        200 ->
          "OK"

        400 ->
          "Bad Request"

        418 ->
          "I'm a teapot"

        404 ->
          "Not Found"

        429 ->
          "Too Many Requests"

        500 ->
          "Internal Server Error"

        501 ->
          "Not Implemented"

        _ ->
          "Unknown"
      end

    headers =
      Map.put(headers, "Content-Length", byte_size(body))

    header_text =
      headers
      |> Enum.map(fn {key, value} ->
        "#{key}: #{value}\r\n"
      end)
      |> Enum.join()

    "HTTP/1.1 #{status} #{fstat}\r\n" <>
      header_text <>
      "\r\n" <>
      body
  end
end

defmodule Deejay.Parser do
  def atom_method(cmd) do
    case cmd do
      "GET" ->
        {:ok, :get}

      "HEAD" ->
        {:ok, :head}

      "OPTIONS" ->
        {:ok, :options}

      "TRACE" ->
        {:ok, :trace}

      "PUT" ->
        {:ok, :put}

      "DELETE" ->
        {:ok, :delete}

      "POST" ->
        {:ok, :post}

      "PATCH" ->
        {:ok, :patch}

      "CONNECT" ->
        {:ok, :connect}

      _ ->
        {:error, :unknown_method}
    end
  end

  def parse_method(src) do
    [method, target, version] = String.split(src, " ")

    case atom_method(method) do
      {:ok, method} ->
        {:ok, method, target, version}

      {:error, reason} ->
        {:error, reason}
    end
  end

  def parse_header(src) do
    case String.split(src, ":", parts: 2) do
      [name, value] ->
        {:ok, {name, String.trim(value)}}

      _ ->
        {:error, :invalid_header}
    end
  end

  def parse_request(src) do
    lines = String.split(src, "\r\n")

    valid_headers = %{
      get: ["host", "user-agent", "accept"],
      post: ["host", "content-type", "content-length"],
      put: ["host", "content-type", "content-length"],
      patch: ["host", "content-type", "content-length"],
      delete: ["host"],
      head: ["host"],
      options: ["host", "allow"],
      connect: ["host"],
      trace: ["host"]
    }

    index = Enum.find_index(lines, &(&1 == ""))

    if index == nil do
      {:error, :invalid_request}
    else
      [request_line | raw_headers] = Enum.take(lines, index)

      body =
        lines
        |> Enum.drop(index + 1)
        |> Enum.join("\r\n")

      with {:ok, method, target, version} <- parse_method(request_line) do
        {path, query} =
          case String.split(target, "?", parts: 2) do
            [path, query] -> {path, query}
            [path] -> {path, nil}
          end

        headers =
          raw_headers
          |> Enum.map(fn header ->
            case parse_header(header) do
              {:ok, {name, value}} ->
                {String.downcase(name), value}

              {:error, reason} ->
                raise "Invalid header: #{reason}"
            end
          end)
          |> Map.new()

        required_headers = Map.get(valid_headers, method, [])

        missing =
          required_headers
          |> Enum.reject(fn required ->
            Map.has_key?(headers, required) == true
          end)

        if missing == [] do
          {:ok,
           %Deejay.Http.Request{
             command: method,
             path: path,
             query: query,
             version: version,
             headers: headers,
             body: body
           }}
        else
          {:error, {:missing_headers, missing}}
        end
      end
    end
  end
end

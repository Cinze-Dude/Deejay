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
      Map.put(headers, "Content-Length", Integer.to_string(byte_size(body)))

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
  defp atom_method(cmd) do
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

  defp parse_method(src) do
    case String.split(src, " ", parts: 3) do
      [method, target, version] ->
        case atom_method(method) do
          {:ok, method} ->
            {:ok, method, target, version}

          {:error, reason} ->
            {:error, reason}
        end

      _ ->
        {:error, :invalid_request_line}
    end
  end

  defp parse_header(src) do
    case String.split(src, ":", parts: 2) do
      [name, value] ->
        {:ok, {name, String.trim(value)}}

      _ ->
        {:error, :invalid_header}
    end
  end

  def parse_request(src) do
    {head, body} =
      case String.split(src, "\r\n\r\n", parts: 2) do
        [head, body] -> {head, body}
        [head] -> {head, ""}
      end

    lines = String.split(head, "\r\n")

    case lines do
      [request_line | raw_headers] ->
        with {:ok, method, target, version} <- parse_method(request_line),
             :ok <- validate_version(version) do
          {path, query} =
            case String.split(target, "?", parts: 2) do
              [path, query] -> {path, query}
              [path] -> {path, nil}
            end

          headers =
            raw_headers
            |> Enum.reduce(%{}, fn header, acc ->
              case parse_header(header) do
                {:ok, {name, value}} ->
                  Map.put(acc, String.downcase(name), value)

                {:error, _} ->
                  acc
              end
            end)

          case validate_request(method, headers, body) do
            :ok ->
              {:ok,
               %Deejay.Http.Request{
                 command: method,
                 path: path,
                 query: query,
                 version: version,
                 headers: headers,
                 body: body
               }}

            {:error, reason} ->
              {:error, reason}
          end
        end

      _ ->
        {:error, :invalid_request}
    end
  end

  defp validate_version("HTTP/1.1"), do: :ok
  defp validate_version(_), do: {:error, :unsupported_version}

  defp validate_request(method, headers, body)
       when method in [:post, :put, :patch] do
    cond do
      not Map.has_key?(headers, "content-length") ->
        {:error, :missing_content_length}

      true ->
        case Integer.parse(headers["content-length"]) do
          {length, ""} when length == byte_size(body) ->
            :ok

          {_, ""} ->
            {:error, :invalid_body_length}

          _ ->
            {:error, :invalid_content_length}
        end
    end
  end

  defp validate_request(_, headers, _) do
    if Map.has_key?(headers, "host") do
      :ok
    else
      {:error, :missing_host}
    end
  end
end

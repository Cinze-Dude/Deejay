defmodule Deejay.Router do
  defmacro __using__(_opts) do
    quote do
      import Deejay.Router

      Module.register_attribute(
        __MODULE__,
        :routes,
        accumulate: true
      )

      @before_compile Deejay.Router
    end
  end

  defmacro get(path, handler) do
    quote do
      @routes {:get, unquote(path), unquote(handler)}
    end
  end

  defmacro post(path, handler) do
    quote do
      @routes {:post, unquote(path), unquote(handler)}
    end
  end

  defmacro put(path, handler) do
    quote do
      @routes {:put, unquote(path), unquote(handler)}
    end
  end

  defmacro delete(path, handler) do
    quote do
      @routes {:delete, unquote(path), unquote(handler)}
    end
  end

  defmacro __before_compile__(env) do
    routes =
      Module.get_attribute(env.module, :routes)
      |> Enum.reverse()

    quote do
      def __routes__ do
        unquote(Macro.escape(routes))
      end
    end
  end

  def route(router, request) do
    routes = router.__routes__()

    case Enum.find(routes, fn {method, path, _handler} ->
           method == request.command and path == request.path
         end) do
      {_method, _path, handler} ->
        handler.handle(request)

      nil ->
        %Deejay.Http.Response{
          status: 404,
          headers: %{
            "Content-Type" => "text/plain"
          },
          body: "Not Found"
        }
    end
  end
end

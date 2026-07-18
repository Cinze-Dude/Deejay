defmodule Deejay.Router do
  def route(%Deejay.Http.Request{command: :get, path: "/"}) do
    %Deejay.Http.Response{
      status: 200,
      headers: %{
        "Content-Type" => "text/html"
      },
      body: "<h1>Hello World</h1>"
    }
  end

  def route(%Deejay.Http.Request{command: :get, path: "/about"}) do
    %Deejay.Http.Response{
      status: 200,
      headers: %{
        "Content-Type" => "text/html"
      },
      body: "<h1>About</h1>"
    }
  end

  def route(%Deejay.Http.Request{}) do
    %Deejay.Http.Response{
      status: 404,
      headers: %{
        "Content-Type" => "text/plain"
      },
      body: "Not Found"
    }
  end
end

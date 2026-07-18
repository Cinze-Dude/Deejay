defmodule Deejay do
  def main() do
    {:ok, _pid} = Deejay.Port.begin_link(port: 1600)
    Process.sleep(:infinity)
  end
end

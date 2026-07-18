defmodule Deejay do
  def start(opts \\ []) do
    {:ok, _pid} = Deejay.Port.begin_link(opts)
    :ok
  end

  def main(opts \\ []) do
    start(opts)
    Process.sleep(:infinity)
  end
end

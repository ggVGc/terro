
defmodule Utils do
  def get_unique_id do
    :crypto.strong_rand_bytes(4) |> :crypto.bytes_to_integer
  end
end

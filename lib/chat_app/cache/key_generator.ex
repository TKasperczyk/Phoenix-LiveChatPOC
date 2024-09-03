defmodule ChatApp.Cache.KeyGenerator do
  def generate(context, user_id \\ nil, params \\ []) do
    base = if user_id, do: "user:#{user_id}:", else: ""
    param_string = Enum.map_join(params, "&", fn {k, v} -> "#{k}=#{v}" end)
    "#{base}#{context}:#{param_string}"
  end
end

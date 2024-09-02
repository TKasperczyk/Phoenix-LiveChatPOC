defmodule ChatApp.Accounts.Avatar do
  alias Mogrify

  @output_folder "priv/static/uploads"

  def store(upload) do
    filename = generate_filename(upload)
    path = Path.join(@output_folder, filename)

    File.cp!(upload.path, path)

    process_avatar(path)

    "/uploads/#{filename}"
  end

  defp generate_filename(upload) do
    extension = Path.extname(upload.client_name)
    "#{Ecto.UUID.generate()}#{extension}"
  end

  defp process_avatar(path) do
    path
    |> Mogrify.open()
    |> Mogrify.resize_to_limit("200x200")
    |> Mogrify.format("jpg")
    |> Mogrify.save(path: path)
  end
end

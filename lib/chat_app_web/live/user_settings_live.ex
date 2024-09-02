defmodule ChatAppWeb.UserSettingsLive do
  use ChatAppWeb, :live_view

  alias ChatApp.Accounts
  alias ChatApp.Accounts.Avatar

  @impl true
  def render(assigns) do
    ~H"""
    <.header class="text-center">
      Account Settings
      <:subtitle>Manage your account email address and password settings</:subtitle>
    </.header>

    <div class="space-y-12 divide-y my-4">
      <div>
        <.form
          for={@avatar_form}
          id="avatar_form"
          phx-submit="update_avatar"
          phx-change="validate_avatar"
        >
          <div class="flex flex-col items-center">
            <div class="mb-4 relative group cursor-pointer">
              <label for={@uploads.avatar.ref} class="cursor-pointer">
                <%= if @current_user.avatar do %>
                  <img
                    src={@current_user.avatar}
                    alt="Current Avatar"
                    class="w-32 h-32 rounded-full object-cover group-hover:opacity-75 transition-opacity duration-300"
                  />
                <% else %>
                  <div class="w-32 h-32 rounded-full bg-gray-300 flex items-center justify-center group-hover:bg-gray-400 transition-colors duration-300">
                    <svg
                      class="w-12 h-12 text-gray-500"
                      fill="none"
                      stroke="currentColor"
                      viewBox="0 0 24 24"
                      xmlns="http://www.w3.org/2000/svg"
                    >
                      <path
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        stroke-width="2"
                        d="M12 6v6m0 0v6m0-6h6m-6 0H6"
                      >
                      </path>
                    </svg>
                  </div>
                <% end %>
                <div class="absolute inset-0 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity duration-300">
                  <span class="bg-black bg-opacity-50 text-white px-2 py-1 rounded text-sm">
                    Change Avatar
                  </span>
                </div>
              </label>
              <.live_file_input upload={@uploads.avatar} class="hidden" />
            </div>

            <%= for entry <- @uploads.avatar.entries do %>
              <div class="mt-4">
                <.live_img_preview entry={entry} class="w-32 h-32 rounded-full object-cover" />
              </div>
            <% end %>

            <.button phx-disable-with="Uploading..." class="mt-4">
              <%= if Enum.empty?(@uploads.avatar.entries),
                do: "Update Avatar",
                else: "Upload New Avatar" %>
            </.button>
          </div>
        </.form>
      </div>
      <div>
        <.simple_form
          for={@email_form}
          id="email_form"
          phx-submit="update_email"
          phx-change="validate_email"
        >
          <.input field={@email_form[:email]} type="email" label="Email" required />
          <.input
            field={@email_form[:current_password]}
            name="current_password"
            id="current_password_for_email"
            type="password"
            label="Current password"
            value={@email_form_current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Email</.button>
          </:actions>
        </.simple_form>
      </div>
      <div>
        <.simple_form
          for={@password_form}
          id="password_form"
          action={~p"/users/log_in?_action=password_updated"}
          method="post"
          phx-change="validate_password"
          phx-submit="update_password"
          phx-trigger-action={@trigger_submit}
        >
          <input
            name={@password_form[:email].name}
            type="hidden"
            id="hidden_user_email"
            value={@current_email}
          />
          <.input field={@password_form[:password]} type="password" label="New password" required />
          <.input
            field={@password_form[:password_confirmation]}
            type="password"
            label="Confirm new password"
          />
          <.input
            field={@password_form[:current_password]}
            name="current_password"
            type="password"
            label="Current password"
            id="current_password_for_password"
            value={@current_password}
            required
          />
          <:actions>
            <.button phx-disable-with="Changing...">Change Password</.button>
          </:actions>
        </.simple_form>
      </div>
    </div>
    """
  end

  @impl true
  def mount(%{"token" => token}, _session, socket) do
    socket =
      case Accounts.update_user_email(socket.assigns.current_user, token) do
        :ok ->
          put_flash(socket, :info, "Email changed successfully.")

        :error ->
          put_flash(socket, :error, "Email change link is invalid or it has expired.")
      end

    {:ok, push_navigate(socket, to: ~p"/users/settings")}
  end

  @impl true
  def mount(_params, _session, socket) do
    user = socket.assigns.current_user
    email_changeset = Accounts.change_user_email(user)
    password_changeset = Accounts.change_user_password(user)
    avatar_changeset = Accounts.change_user_avatar(user)

    socket =
      socket
      |> assign(:avatar_form, to_form(avatar_changeset))
      |> allow_upload(:avatar, accept: ~w(.jpg .jpeg .png), max_entries: 1)
      |> assign(:current_password, nil)
      |> assign(:email_form_current_password, nil)
      |> assign(:current_email, user.email)
      |> assign(:email_form, to_form(email_changeset))
      |> assign(:password_form, to_form(password_changeset))
      |> assign(:trigger_submit, false)

    {:ok, socket}
  end

  @impl true
  def handle_event("validate_avatar", _params, socket) do
    {:noreply, socket}
  end

  @impl true
  def handle_event("update_avatar", _params, socket) do
    user = socket.assigns.current_user

    case consume_uploaded_entries(socket, :avatar, fn %{path: path}, _entry ->
           {:ok, Avatar.store(%{path: path, client_name: Path.basename(path)})}
         end) do
      [avatar_url] ->
        case Accounts.update_user_avatar(user, %{avatar: avatar_url}) do
          {:ok, updated_user} ->
            {:noreply,
             socket
             |> assign(:current_user, updated_user)
             |> put_flash(:info, "Avatar updated successfully.")}

          {:error, changeset} ->
            {:noreply, assign(socket, :avatar_form, to_form(changeset))}
        end

      _ ->
        {:noreply, socket |> put_flash(:error, "Avatar upload failed.")}
    end
  end

  @impl true
  def handle_event("validate_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    email_form =
      socket.assigns.current_user
      |> Accounts.change_user_email(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, email_form: email_form, email_form_current_password: password)}
  end

  def handle_event("update_email", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.apply_user_email(user, password, user_params) do
      {:ok, applied_user} ->
        Accounts.deliver_user_update_email_instructions(
          applied_user,
          user.email,
          &url(~p"/users/settings/confirm_email/#{&1}")
        )

        info = "A link to confirm your email change has been sent to the new address."
        {:noreply, socket |> put_flash(:info, info) |> assign(email_form_current_password: nil)}

      {:error, changeset} ->
        {:noreply, assign(socket, :email_form, to_form(Map.put(changeset, :action, :insert)))}
    end
  end

  def handle_event("validate_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params

    password_form =
      socket.assigns.current_user
      |> Accounts.change_user_password(user_params)
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, password_form: password_form, current_password: password)}
  end

  def handle_event("update_password", params, socket) do
    %{"current_password" => password, "user" => user_params} = params
    user = socket.assigns.current_user

    case Accounts.update_user_password(user, password, user_params) do
      {:ok, user} ->
        password_form =
          user
          |> Accounts.change_user_password(user_params)
          |> to_form()

        {:noreply, assign(socket, trigger_submit: true, password_form: password_form)}

      {:error, changeset} ->
        {:noreply, assign(socket, password_form: to_form(changeset))}
    end
  end
end

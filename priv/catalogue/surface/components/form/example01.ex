defmodule Surface.Components.Form.Example01 do
  use Surface.Catalogue.Example,
    catalogue: Surface.Components.Catalogue,
    subject: Surface.Components.Form,
    height: "350px",
    direction: "vertical"

  alias Surface.Components.Form.{TextInput, Label, Field}

  data user, :map, default: %{"name" => "", "email" => ""}

  def render(assigns) do
    ~H"""
    <Form for={{ :user }} change="change" submit="submit" opts={{ autocomplete: "off" }}>
      <Field class="field" name="name">
        <Label class="label"/>
        <div class="control">
          <TextInput class="input" value={{ @user["name"] }}/>
        </div>
      </Field>
      <Field class="field" name="email">
        <Label class="label">E-mail</Label>
        <div class="control">
          <TextInput class="input" value={{ @user["email"] }}/>
        </div>
      </Field>
    </Form>

    <pre>@user = {{ Jason.encode!(@user, pretty: true) }}</pre>
    """
  end

  def handle_event("change", %{"user" => params}, socket) do
    {:noreply, assign(socket, :user, params)}
  end
end

defmodule HyadesWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use HyadesWeb, :html

  # Embed all files in layouts/* within this module.
  # The default root.html.heex file contains the HTML
  # skeleton of your application, namely HTML headers
  # and other static content.
  embed_templates("layouts/*")

  @doc """
  The main application layout.

  This layout is used as an explicit function component call in templates.
  It provides the common structure for authenticated pages including
  header, navigation, and flash messages.

  ## Examples

      <Layouts.app flash={@flash}>
        <p>Your page content here</p>
      </Layouts.app>

  """
  attr(:flash, :map, required: true, doc: "the map of flash messages")
  attr(:page_title, :string, default: nil, doc: "optional page title")
  slot(:inner_block, required: true, doc: "the inner content to render")
  attr(:nav_active, :atom, default: nil, doc: "active nav key, e.g., :models")

  def app(assigns)
end

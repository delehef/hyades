defmodule HyadesWeb.Pow.Messages do
  use Pow.Phoenix.Messages
  use Pow.Extension.Phoenix.Messages, extensions: [PowResetPassword, PowAssent]

  ##
  ## Pow
  ##
  @impl true
  def invalid_credentials(_conn), do: "Incorrect credentials; please try again"

  @impl true
  def user_has_been_updated(_conn), do: "Your settings have been saved"

  ##
  ## PowResetPassword
  ##
  def pow_reset_password_email_has_been_sent(_conn),
    do: "You have been sent an email with a link to reset your password"

  def pow_reset_password_password_has_been_reset(_conn),
    do: "Your password has been successfully reset"
end

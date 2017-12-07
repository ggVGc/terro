defmodule Terro.Web do
  def controller do
    quote do
      use Phoenix.Controller
      import Terro.Router.Helpers
    end
  end
end

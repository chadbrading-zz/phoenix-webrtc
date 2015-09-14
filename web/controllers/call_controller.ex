defmodule VideoChat.CallController do
  use VideoChat.Web, :controller

  def index(conn, _params) do
    render conn, :index
  end
end

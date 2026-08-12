require "test_helper"

class RemovedAdministrationRoutesTest < ActionDispatch::IntegrationTest
  test "obsolete administration paths are not routable" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/plat" + "form_admin", method: :get)
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/admin", method: :get)
    end
  end
end

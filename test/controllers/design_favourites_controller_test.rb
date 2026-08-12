require "test_helper"

class DesignFavouritesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in users(:owner) }

  test "favourite updates only its Turbo frame" do
    design = designs(:blouse_reference)

    assert_difference("DesignFavourite.count", 1) do
      post design_favourite_path(design, compact: 1), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end

    assert_response :success
    assert_equal "text/vnd.turbo-stream.html", response.media_type
    assert_includes response.body, "favourite_design_#{design.id}"

    assert_difference("DesignFavourite.count", -1) do
      delete design_favourite_path(design, compact: 1), headers: { "Accept" => "text/vnd.turbo-stream.html" }
    end
    assert_response :success
  end
end

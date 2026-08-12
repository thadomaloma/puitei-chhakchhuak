require "test_helper"

class ApplicationHelperTest < ActionView::TestCase
  test "renders consistent decorative icon markup" do
    markup = ui_icon("orders", size: 18)

    assert_dom_equal <<~HTML.squish, markup
      <svg viewBox="0 0 24 24" width="18" height="18" fill="none" stroke="currentColor" stroke-width="1.75" stroke-linecap="round" stroke-linejoin="round" class="shrink-0" aria-hidden="true"><path d="M9 5h6"></path><path d="M9 3h6v4H9z"></path><path d="M6 5H5a2 2 0 0 0-2 2v13a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-1"></path><path d="M8 12h8"></path><path d="M8 16h5"></path></svg>
    HTML
  end

  test "labelled icon exposes an accessible title" do
    document = Nokogiri::HTML.fragment(ui_icon("warning", label: "Attention"))

    assert_equal "img", document.at_css("svg")["role"]
    assert_equal "Attention", document.at_css("title").text
    assert_nil document.at_css("svg")["aria-hidden"]
  end

  test "status badge includes readable text and semantic status key" do
    document = Nokogiri::HTML.fragment(status_badge("completed"))

    assert_equal "Completed", document.text
    assert_includes document.at_css("span")["class"], "status-success"
    assert_equal "completed", document.at_css("span")["data-status"]
  end

  test "initials use the first two name parts" do
    assert_equal "LC", initials_for("Lalruatkima Chhangte")
  end
end

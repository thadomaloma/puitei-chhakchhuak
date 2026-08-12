require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1440, 1000 ]

  private

  def sign_in_as(user)
    visit new_user_session_path
    fill_in User.human_attribute_name(:email), with: user.email
    fill_in User.human_attribute_name(:password), with: "Password-123!"
    click_button I18n.t("sessions.sign_in")
    assert_current_path root_path
  end

  def assert_responsive_document
    assert_selector "main#main-content", count: 1
    assert_selector "h1", minimum: 1
    assert_equal page.evaluate_script("document.documentElement.scrollWidth <= window.innerWidth"), true

    unnamed_buttons = page.evaluate_script(<<~JAVASCRIPT)
      Array.from(document.querySelectorAll("button, [role='button']")).filter((element) => {
        const style = window.getComputedStyle(element)
        const visible = style.display !== "none" && style.visibility !== "hidden"
        const name = element.getAttribute("aria-label") || element.getAttribute("title") || element.textContent
        return visible && !name.trim()
      }).length
    JAVASCRIPT
    assert_equal 0, unnamed_buttons
  end

  def sign_out_current_user
    click_button I18n.t("sessions.sign_out"), match: :first
    assert_current_path new_user_session_path
  end
end

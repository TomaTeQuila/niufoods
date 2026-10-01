require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  test "root serves the React dashboard mount point and local bundle" do
    get "/"
    assert_response :success
    assert_select "title", "Panel de pedidos"
    assert_select "#orders-dashboard"
    assert_select 'script[src*="dashboard"]'
    assert_select 'link[href*="orders-dashboard.css"]'
  end
end

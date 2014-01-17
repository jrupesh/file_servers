require File.expand_path('../../test_helper', __FILE__)

class FileServersControllerTest < ActionController::TestCase
	fixtures :projects, :file_servers

  def setup
    User.current = nil
    @request.session[:user_id] = 1 # admin
  end

	def test_check_for_plugin_menu
    # get :index
    # assert_response :success
    # assert_select "title", "File servers"
	end

end

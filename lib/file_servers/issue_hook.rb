module FileServers
	class IssueHook < Redmine::Hook::ViewListener
	  def controller_issues_new_after_save(context={ })
	    # move_to_alien_files_folder
	    puts " ---------- PARAMS ---- #{context} ------------ "

	  end

	  def controller_issues_edit_after_save(context={ })
	    # move_to_alien_files_folder
	    puts " ---------- PARAMS ---- #{context} ------------ "
	  end
	end
end
require File.expand_path('../../test_helper', __FILE__)

class FileServerTest < ActiveSupport::TestCase

	fixtures :file_servers, :projects

  def test_initialize
    fileserver = FileServer.new
    assert_nil fileserver.name
    assert_nil fileserver.address
    assert_nil fileserver.port
    assert_nil fileserver.root
    assert_nil fileserver.login
    assert_nil fileserver.password
    assert_nil fileserver.autoscan
    assert_equal "ftp", fileserver.type_name
  end

  test "should validate attributes" do
  	attribs = {:name => "TestFileServer", :address => "127.0.0.1",
                      :login => "redmine", :password => 'redmine', :port => 80, 
                      :root => "fileserver/root", :autoscan => true, :protocol => 0}

    fileserver = FileServer.new(attribs.except(:name))
    assert !fileserver.save

    fileserver = FileServer.new(attribs.except(:address))
    assert !fileserver.save

    fileserver = FileServer.new(attribs)
    fileserver.name = "a" * 51
    assert !fileserver.save

    fileserver = FileServer.new(attribs)
    fileserver.address = "a" * 121
    assert !fileserver.save

    fileserver = FileServer.new(attribs.except(:port))
    assert fileserver.save

    fileserver.port = nil
    assert fileserver.save

    fileserver = FileServer.new(attribs.except(:port))
    fileserver.port = "stringValue"
    assert !fileserver.save

    fileserver = FileServer.new(attribs.except(:port))
    fileserver.port = "80"
    assert fileserver.save

    fileserver = FileServer.new(attribs)
    fileserver.root = "a" * 121
    assert !fileserver.save

    fileserver = FileServer.new(attribs)
    fileserver.login = "a" * 41
    assert !fileserver.save

    fileserver = FileServer.new(attribs)
    fileserver.password = "a" * 121
    assert !fileserver.save

    fileserver = FileServer.new(attribs.except(:protocol))
    assert fileserver.save
	end

  def test_create
    fileserver = FileServer.new(:name => "TestFileServer", :address => "127.0.0.1",
                      :login => "redmine", :password => 'redmine')
    assert fileserver.save
    fileserver.reload
    assert_equal "TestFileServer", fileserver.name
    assert_equal "127.0.0.1", fileserver.address
  end

  def test_create_all
    fileserver = FileServer.new(:name => "TestFileServer", :address => "127.0.0.1",
                      :login => "redmine", :password => 'redmine', :port => 80, :root => "fileserver/root",
                      :autoscan => true, :protocol => 0 )
    assert fileserver.save
    fileserver.reload
    assert fileserver.autoscan, "Autoscan is true"
    assert_equal "127.0.0.1", fileserver.address
    assert_equal 80, fileserver.port
  end

  def test_update
    fileserver = FileServer.create!(:name => "TestFileServer", :address => "127.0.0.1",
                      :login => "redmine", :password => 'redmine')
    fileserver.reload

    fileserver.name = "NewName123"
    fileserver.address = "127.0.0.99"
    assert fileserver.save , "Failed to save."
    
    fileserver.reload
    assert_equal "NewName123", fileserver.name
    assert_equal "127.0.0.99", fileserver.address
  end

  def test_destroy
    status = FileServer.find(3)
    assert_difference 'FileServer.count', -1 do
      assert status.destroy
    end
    assert_nil FileServer.find_by_id(status.id)
  end

  test "should associate a project to fileserver" do
  	fileserver = FileServer.find(3)
  	assert_equal 0, fileserver.projects.length
  	project = Project.find(1)
  	fileserver.projects = [project]

  	fileserver.reload
  	assert_equal 1, fileserver.projects.length

  	project.reload
		assert_equal FileServer, project.file_server.class
  end

end

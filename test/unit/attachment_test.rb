# encoding: utf-8
#
# Redmine - project management software
# Copyright (C) 2006-2013  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

require File.expand_path('../../test_helper', __FILE__)

class AttachmentTest < ActiveSupport::TestCase
  fixtures :file_servers, :projects, :issues, :attachments, :users
  
  class MockFile
    attr_reader :original_filename, :content_type, :content, :size
    
    def initialize(attributes)
      @original_filename = attributes[:original_filename]
      @content_type = attributes[:content_type]
      @content = attributes[:content] || "Content"
      @size = content.size
    end
  end

  def setup
    Setting.plugin_file_servers["organize_uploaded_files"] = "on"
    p = Project.find(1)
    p.file_server = FileServer.find(1)
    p.save
  end

  test "Attachmnet.attach_files should attach the file" do
    issue = Issue.first
    assert_difference 'Attachment.count' do
      Attachment.attach_files(issue,
        '1' => {
          'file' => fixture_file_upload("/files/testfile.txt", 'text/plain', true),
          'description' => 'test'
        })
    end

    attachment = Attachment.first(:order => 'id DESC')
    assert_equal issue, attachment.container
    assert_equal 'testfile.txt', attachment.filename
    assert_equal 61, attachment.filesize
    assert_equal 'test', attachment.description
    assert_equal 'text/plain', attachment.content_type
    # assert File.exists?(attachment.diskfile)
    # assert_equal 61, File.size(attachment.diskfile)
  end

  test "Attachmnet.attach_files should add unsaved files to the object as unsaved attachments" do
    # Max size of 0 to force Attachment creation failures
    with_settings(:attachment_max_size => 0) do
      @project = Project.find(1)
      response = Attachment.attach_files(@project, {
                                           '1' => {'file' => mock_file, 'description' => 'test'},
                                           '2' => {'file' => mock_file, 'description' => 'test'}
                                         })

      assert response[:unsaved].present?
      assert_equal 2, response[:unsaved].length
      assert response[:unsaved].first.new_record?
      assert response[:unsaved].second.new_record?
      assert_equal response[:unsaved], @project.unsaved_attachments
    end
  end

  def test_destroy
    a = Attachment.new(:container => Issue.find(1),
                       :file => fixture_file_upload("/files/testfile.txt", 'text/plain', true),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.txt', a.filename
    assert_equal 61, a.filesize
    assert_equal 'text/plain', a.content_type
    assert_equal 0, a.downloads
    assert_equal '31e3389f8cd52c31351f8984e3c24bbd', a.digest
    assert a.ftpfileexists?
    assert a.destroy
    assert !a.ftpfileexists?
  end

  test "Attach to a document" do
    doc = Document.new(:project => Project.find(1), :title => 'New document', :category => Enumeration.find_by_name('User documentation'))
    doc.save
    a = Attachment.new(:container => doc,
                       :file => fixture_file_upload("/files/testfile.txt", 'text/plain', true),
                       :author => User.find(1))
    assert a.save
    assert_equal 'testfile.txt', a.filename
    assert_equal 61, a.filesize
    assert_equal 'text/plain', a.content_type
    assert_equal 0, a.downloads
    assert_equal '31e3389f8cd52c31351f8984e3c24bbd', a.digest
    assert a.ftpfileexists?
    assert a.destroy
    assert !a.ftpfileexists?
  end
end

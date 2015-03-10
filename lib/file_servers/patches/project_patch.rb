module FileServers
  module Patches
    module ProjectPatch

      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          belongs_to :file_server
          safe_attributes 'file_server_id'
        end
      end

      module ClassMethods
      end

      module InstanceMethods

        def has_file_server?
          Setting.plugin_file_servers["organize_uploaded_files"] == "on" && !self.file_server.nil?
        end

        def proj_tree_path
          n = ""
          p = self
          begin
            n = n.blank? ? p.name : p.name + " >> " + n
            p = p.parent
          end while p
          n
        end
      end
    end
  end
end
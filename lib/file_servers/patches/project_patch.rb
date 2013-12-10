module FileServers
  module Patches
    module ProjectPatch
      
      def self.included(base) # :nodoc:
        base.extend(ClassMethods)
        base.send(:include, InstanceMethods)

        base.class_eval do
          unloadable
          belongs_to :file_server
        end
      end

      module ClassMethods
      end

      module InstanceMethods

        def has_file_server?
          !self.file_server.nil?
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
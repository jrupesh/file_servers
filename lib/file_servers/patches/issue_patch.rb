module FileServers
  module Patches
    module IssuePatch
      def self.included(base) # :nodoc:
        base.class_eval do
          unloadable
          after_create :create_alien_files_folder
        end
      end
    end
  end
end
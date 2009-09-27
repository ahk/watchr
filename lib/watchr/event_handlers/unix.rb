require 'rev'
require 'ruby-debug'

module Watchr
  module EventHandler
    class Unix
      include Base

      # Used by Rev. Wraps a monitored path, and Rev::Loop will call its
      # callback on file events.
      class SingleFileWatcher < Rev::StatWatcher #:nodoc:
        class << self
          # Stores a reference back to handler so we can call its #nofity
          # method with file event info
          attr_accessor :handler
        end
        
        attr_accessor :last_atime, :last_ctime, :last_mtime
        
        def initialize path
          @last_atime = stat_time_for :atime
          @last_mtime = stat_time_for :mtime
          @last_ctime = stat_time_for :ctime
          super
        end
        
        # Callback. Called on file change event
        # Delegates to Controller#update, passing in path and event type
        # ignore anything but modified file content
        def on_change
          if stat_changed? :mtime
            update_stat_times!
            self.class.handler.notify(@path, :changed)
          end
        end
        
      private
        def update_stat_times!
          %w(atime mtime ctime).each do |stat|
            time = self.send( :stat_time_for, stat )
            self.send "last_#{stat}=", time
          end
        end
        
        def stat_changed? stat
          self.send("last_#{stat}") < stat_time_for(stat)
        end
        
        def stat_time_for stat
          File.send stat.to_sym, @path
        end
      end # SingleFileWatcher

      def initialize
        SingleFileWatcher.handler = self
        @loop = Rev::Loop.default
      end

      # Enters listening loop.
      #
      # Will block control flow until application is explicitly stopped/killed.
      #
      def listen(monitored_paths)
        @monitored_paths = monitored_paths
        attach
        @loop.run
      end

      # Rebuilds file bindings.
      #
      # will detach all current bindings, and reattach the <tt>monitored_paths</tt>
      #
      def refresh(monitored_paths)
        @monitored_paths = monitored_paths
        detach
        attach
      end

      private

      # Binds all <tt>monitored_paths</tt> to the listening loop.
      def attach
        @monitored_paths.each {|path| SingleFileWatcher.new(path.to_s).attach(@loop) }
      end

      # Unbinds all paths currently attached to listening loop.
      def detach
        @loop.watchers.each {|watcher| watcher.detach }
      end
    end
  end
end

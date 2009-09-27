require 'test/test_helper'

class UnixEventHandlerTest < Test::Unit::TestCase
  include Watchr

  SingleFileWatcher = EventHandler::Unix::SingleFileWatcher

  def setup
    @loop    = Rev::Loop.default
    @handler = EventHandler::Unix.new
    @loop.stubs(:run)
    
    @now = Time.now
    stub_stat_time @now                       # fakes initial stat
    @watcher = SingleFileWatcher.new('foo/bar')
    @watcher.stubs(:path).returns('foo/bar')
    stub_stat_time @now + 10                  # fakes a file change
  end

  def teardown
    SingleFileWatcher.handler = nil
    Rev::Loop.default.watchers.every.detach
  end

  test "triggers listening state" do
    @loop.expects(:run)
    @handler.listen([])
  end

  ## monitoring file events

  test "listens for events on monitored files" do
    @handler.listen %w( foo bar )
    @loop.watchers.size.should be(2)
    @loop.watchers.every.path.should include('foo', 'bar')
    @loop.watchers.every.class.uniq.should be([SingleFileWatcher])
  end
  
  test "notifies observers on file event" do
    @handler.expects(:notify).with('foo/bar', :changed)
    @watcher.on_change
  end
  
  test "compares and updates useful stat info" do
    # stat change
    @watcher.last_mtime.should be(@now)
    @watcher.on_change
    @watcher.last_mtime.should be(@now + 10)
    
    # no stat change
    stub_stat_time @now
    @watcher.last_mtime = @now
    @watcher.on_change
    @watcher.last_mtime.should be(@now)
  end

  ## on the fly updates of monitored files list

  test "reattaches to new monitored files" do
    @handler.listen %w( foo bar )
    @loop.watchers.size.should be(2)
    @loop.watchers.every.path.should include('foo')
    @loop.watchers.every.path.should include('bar')

    @handler.refresh %w( baz bax )
    @loop.watchers.size.should be(2)
    @loop.watchers.every.path.should include('baz')
    @loop.watchers.every.path.should include('bax')
    @loop.watchers.every.path.should exclude('foo')
    @loop.watchers.every.path.should exclude('bar')
  end
  
  private
  # File.atime "foo/bar/baz" => Time
  def stub_stat_time now
    %w(atime ctime mtime).each do |s|
      File.stubs(s).with {|p| p.is_a? String}.returns(now)
    end
  end
end

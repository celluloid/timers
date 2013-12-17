require 'set'
require 'forwardable'
require 'timers/version'
require 'hitimes'
require 'tod'
require 'parse-cron'

# Workaround for thread safety issues in SortedSet initialization
# See: https://github.com/celluloid/timers/issues/20
SortedSet.new

class Timers
  include Enumerable
  extend  Forwardable
  def_delegators :@timers, :delete, :each, :empty?
  ONE_DAY_IN_SECONDS = 86400

  def initialize
    @timers = SortedSet.new
    @paused_timers = SortedSet.new
    @interval = Hitimes::Interval.new
    @interval.start
  end

  # Call the given block using cron notation
  #e.g cron('* * * * *') { puts "Hi" } will puts hi every min
  def cron(time, &block)
    cron_parser = CronParser.new(time)
    interval = cron_parser.next - Time.now
    Timer.new(self, interval, true, cron_parser, &block)
  end

  # Call the given block at a given time in a human readable format
  def at(time, recurring = false, &block)
    sleep_at = TimeOfDay.parse(time).second_of_day
    time_now = Time.now.to_time_of_day.second_of_day
    interval = sleep_at - time_now

    if recurring
      after(interval) { block.call; every(ONE_DAY_IN_SECONDS, &block) }
    else
      after(interval, &block)
    end
  end

  # Call the given block at the same time every day in a human readable format
  def recurring_at(time, &block)
    at(time, true, &block)
  end

  # Call the given block after the given interval
  def after(interval, &block)
    Timer.new(self, interval, false, false, &block)
  end

  # Call the given block after the given interval has expired. +interval+
  # is measured in milliseconds.
  #
  #  Timer.new.after_milliseconds(25) { puts "fired!" }
  #
  def after_milliseconds(interval, &block)
    after(interval / 1000.0, &block)
  end
  alias_method :after_ms, :after_milliseconds

  # Call the given block periodically at the given interval
  def every(interval, &block)
    Timer.new(self, interval, true, false, &block)
  end

  # Wait for the next timer and fire it
  def wait
    i = wait_interval
    sleep i if i
    fire
  end

  # Interval to wait until when the next timer will fire
  def wait_interval(offset = self.current_offset)
    timer = @timers.first
    return unless timer
    interval = timer.offset - Float(offset)
    interval > 0 ? interval : 0
  end

  # Fire all timers that are ready
  def fire(offset = self.current_offset)
    time = Float(offset) + 0.001 # Fudge 1ms in case of clock imprecision
    while (timer = @timers.first) && (time >= timer.offset)
      @timers.delete timer
      timer.fire(offset)
    end
  end

  def add(timer)
    raise TypeError, "not a Timers::Timer" unless timer.is_a? Timers::Timer
    @timers.add(timer)
  end

  def pause(timer = nil)
    return pause_all if timer.nil?
    raise TypeError, "not a Timers::Timer" unless timer.is_a? Timers::Timer
    @timers.delete timer
    @paused_timers.add timer
  end

  def pause_all
    @timers.each {|timer| timer.pause}
  end

  def continue(timer = nil)
    return continue_all if timer.nil?
    raise TypeError, "not a Timers::Timer" unless timer.is_a? Timers::Timer
    @paused_timers.delete timer
    @timers.add timer
  end

  def continue_all
    @paused_timers.each {|timer| timer.continue}
  end

  def delay(seconds)
    @timers.each {|timer| timer.delay(seconds)}
  end

  alias_method :cancel, :delete

  def current_offset
    @interval.to_f
  end

  # An individual timer set to fire a given proc at a given time
  class Timer
    include Comparable
    attr_reader :interval, :offset, :recurring

    def initialize(timers, interval, recurring = false, cron = false, &block)
      @timers, @interval, @recurring, @cron = timers, interval, recurring, cron
      @block  = block
      @offset = nil

      reset
    end

    def <=>(other)
      @offset <=> other.offset
    end

    # Cancel this timer
    def cancel
      @timers.cancel self
    end

    # Extend this timer
    def delay(seconds)
      @timers.delete self
      @offset += seconds
      @timers.add self
    end

    # Reset this timer
    def reset(offset = @timers.current_offset)
      @timers.cancel self if @time
      if @cron
        interval = @cron.next - Time.now
        @offset = Float(offset) + interval
      else
        @offset = Float(offset) + @interval
      end
      @timers.add self
    end

    # Fire the block
    def fire(offset = @timers.current_offset)
      reset(offset) if recurring
      @block.call
    end
    alias_method :call, :fire

    # Pause this timer
    def pause
      @timers.pause self
    end

    # Continue this timer
    def continue
      @timers.continue self
    end

    # Inspect a timer
    def inspect
      str = "#<Timers::Timer:#{object_id.to_s(16)} "
      offset = @timers.current_offset

      if @offset
        if @offset >= offset
          str << "fires in #{@offset - offset} seconds"
        else
          str << "fired #{offset - @offset} seconds ago"
        end

        str << ", recurs every #{interval}" if recurring
      else
        str << "dead"
      end

      str << ">"
    end
  end
end

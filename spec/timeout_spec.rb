# Copyright, 2014, by Samuel G. D. Williams. <http://www.codeotaku.com>
# This code is released under the MIT license. See the LICENSE file for more details.

require 'spec_helper'
require 'timers/timeout'

describe Timers::Timeout do
  # Level of accuracy enforced by tests (50ms)
  Q = 0.05

  it "repeats until timeout expired" do
    timeout = Timers::Timeout.new(5)
    count = 0
    
    timeout.while_time_remaining do |remaining|
      expect(remaining).to be_within(Q).of (timeout.duration - count)
      
      count += 1
      sleep 1
    end
    
    expect(count).to eq(5)
  end
  
  it "yields results as soon as possible" do
    timeout = Timers::Timeout.new(5)
    
    result = timeout.while_time_remaining do |remaining|
      break :done
    end
    
    expect(result).to eq(:done)
  end
end

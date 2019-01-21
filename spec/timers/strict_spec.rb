# frozen_string_literal: true
#
# This file is part of the "timers" project and released under the MIT license.
#
# Copyright, 2018, by Samuel Williams. All rights reserved.
#

RSpec.describe Timers::Group do
	it "should not diverge too much" do
		fired = :not_fired_yet
		count = 0
		quantum = 0.01

		start_offset = subject.current_offset
		Timers::Timer.new(subject, quantum, :strict, start_offset) do |offset|
			fired = offset
			count += 1
		end

		iterations = 1000
		subject.wait while count < iterations

		# In my testing on the JVM, without the :strict recurring, I noticed 60ms of error here.
		expect(fired - start_offset).to be_within(quantum).of(iterations * quantum)
	end

	it "should only fire once" do
		fired = :not_fired_yet
		count = 0

		start_offset = subject.current_offset
		Timers::Timer.new(subject, 0, :strict, start_offset) do |offset, timer|
			fired = offset
			count += 1

			timer.cancel
		end

		subject.wait

		expect(count).to be == 1
	end
end

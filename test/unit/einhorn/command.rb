require File.expand_path(File.join(File.dirname(__FILE__), '../../_lib'))

require 'einhorn'

class CommandTest < EinhornTestCase
  include Einhorn

  describe "when running quieter" do
    it "increases the verbosity threshold" do
      Einhorn::State.stubs(:verbosity => 1)
      Einhorn::State.expects(:verbosity=).once.with(2).returns(2)
      Command.quieter
    end

    it "maxes out at 2" do
      Einhorn::State.stubs(:verbosity => 2)
      Einhorn::State.expects(:verbosity=).never
      Command.quieter
    end
  end

  describe "resignal_timeout" do
    it "does not kill any children" do
      Einhorn::State.stubs(signal_timeout: 5 * 60)
      Einhorn::State.stubs(children: {
        12345 => {last_signaled_at: nil},
        12346 => {signaled: Set.new(["USR1"]), last_signaled_at: Time.now - (2 * 60)},
      })

      Process.expects(:kill).never
      Einhorn::Command.kill_expired_signaled_workers

      refute(Einhorn::State.children[12346][:signaled].include?("KILL"), "Process was KILLed when it shouldn't have been")
    end

    it "KILLs stuck child processes" do
      Time.stub :now, Time.at(0) do
        Process.stub(:kill, true) do
          Einhorn::State.stubs(signal_timeout: 60)
          Einhorn::State.stubs(children: {
            12346 => {signaled: Set.new(["USR2"]), last_signaled_at: Time.now - (2 * 60)},
          })

          Einhorn::Command.kill_expired_signaled_workers

          child = Einhorn::State.children[12346]
          assert(child[:signaled].include?("KILL"), "Process was not KILLed as expected")
          assert(child[:last_signaled_at] == Time.now, "The last_processed_at was not updated as expected")
        end
      end
    end
  end
end

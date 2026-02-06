# frozen_string_literal: false

require 'rspec'
require 'rbconfig'
require 'timeout'

RSpec.describe 'JRuby' do
  let(:warning_pattern) do
    /\s+warning:\s+already initialized constant/i
  end

  def jruby?
    defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby'
  end

  describe 'when a shutdown hook thread interacts with other threads' do
    it 'emits already initialized constant warning' do
      skip 'JRuby only, please' unless jruby?

      r_out, w_out = IO.pipe
      r_err, w_err = IO.pipe

      comprehensive_output = +""
      stderr = +""

      code = <<~RUBY
        $VERBOSE = true
        $stderr.sync = true
        $stdout.sync = true

        require File.expand_path('lib/example', Dir.pwd)
        EchoServer.new.run
      RUBY

      pid = Process.spawn(
        RbConfig.ruby,
        '-rbundler/setup',
        '-e',
        code,
        out: w_out,
        err: w_err,
        pgroup: true
      )

      w_out.close
      w_err.close

      out_reader = Thread.new do
        begin
          loop do
            msg = r_out.readpartial(16_384)
            comprehensive_output << msg
          end
        rescue EOFError
          nil
        end
      end

      err_reader = Thread.new do
        begin
          loop do
            msg = r_err.readpartial(16_384)
            comprehensive_output << msg
            stderr << msg
          end
        rescue EOFError
          nil
        end
      end

      reaped = false

      begin
        Timeout.timeout(20) do
          loop do
            break if comprehensive_output.include?('Listening on')
            w = Process.waitpid(pid, Process::WNOHANG)
            if w
              reaped = true
              raise "Child exited early.\nstdout:\n#{comprehensive_output}\nstderr:\n#{stderr}"
            end
            sleep 0.05
          end
        end

        Process.kill("INT", -pid)

        Timeout.timeout(20) do
          loop do
            break if stderr.match?(warning_pattern)

            w = Process.waitpid(pid, Process::WNOHANG)
            if w
              reaped = true
              break
            end

            sleep 0.05
          end
        end

        unless reaped
          begin
            Timeout.timeout(5) do
              Process.wait(pid)
              reaped = true
            end
          rescue Timeout::Error
            nil
          rescue Errno::ECHILD
            reaped = true
          end
        end
      ensure
        begin
          Process.kill("KILL", -pid)
        rescue StandardError
          nil
        end

        unless reaped
          begin
            Process.wait(pid)
          rescue Errno::ECHILD
            nil
          end
        end
      end

      r_out.close
      r_err.close
      out_reader.join
      err_reader.join

      expect(stderr).to match(warning_pattern)

      puts "comprehensive output:"
      puts comprehensive_output
      puts "-------"
    end
  end
end

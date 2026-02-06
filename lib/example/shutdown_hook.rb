# encoding: utf-8
# frozen_string_literal: false

# -*- mode: ruby -*-
# vi: set ft=ruby :

# =begin
#
# Copyright Nels Nelson 2016-2026 but freely usable (see license)
#
# =end

require 'java'

# The TcpServer module
module Example
  # The ShutdownHook class specifies a routine to be invoked when the
  # java runtime is shutdown.
  class ShutdownHook < java.lang.Thread
    attr_reader :server

    def initialize(server)
      super()
      @server = server
      java.lang.Runtime.runtime.add_shutdown_hook(self)
    end

    def run
      $stdout.write "\r\e[0K"
      $stdout.flush
      @server&.shutdown if @server.respond_to?(:shutdown)
    rescue StandardError => e
      $stderr.puts e.message
      $stderr.flush
    end
  end
end

# encoding: utf-8
# frozen_string_literal: false

# -*- mode: ruby -*-
# vi: set ft=ruby :

# =begin

# Copyright Nels Nelson 2016-2026 but freely usable (see license)

# =end

def jruby?
  defined?(RUBY_ENGINE) && RUBY_ENGINE == 'jruby' && defined?(Java)
end

if jruby?
  require 'java'
  require 'apache-log4j-2'

  java_import 'org.apache.logging.log4j.Level'
  java_import 'org.apache.logging.log4j.core.config.builder.api.' \
    'ConfigurationBuilderFactory'
  java_import 'org.apache.logging.log4j.core.appender.ConsoleAppender'
  java_import 'org.apache.logging.log4j.core.config.Configurator'
  java_import 'org.apache.logging.log4j.core.LoggerContext'
  java_import 'org.apache.logging.log4j.LogManager'
  java_import 'org.apache.logging.log4j.ThreadContext'
end

require 'fileutils'
require 'logger'

# The Logging module
module Logging
  module_function

  def logger_app_name
    'app'
  end

  def backend
    @backend ||= begin
      if jruby?
        init_log4j2!
        apply_backend_level(log_level)
        LogManager.getLogger(logger_app_name)
      else
        log = Logger.new($stdout)
        log.formatter = method(:ruby_formatter)
        @backend = log
        apply_backend_level(log_level)
        log
      end
    end
  end

  def logger
    @proxy ||= Proxy.new
  end
  alias log logger

  def ruby_formatter(severity, datetime, _progname, msg)
    category = (Thread.current[:logging_category] || logger_app_name).to_s
    timestamp = datetime.strftime("%Y-%m-%d %H:%M:%S")
    format("%<timestamp>s %-5<severity>s [%<category>s] %<msg>s\n",
      timestamp: timestamp,
      severity: severity,
      category: category,
      msg: msg)
  end

  def init_log4j2!
    return if @log4j2_initialized

    Java::java.lang.System.setProperty(
      "log4j.shutdownHookEnabled",
      Java::java.lang.Boolean.toString(false)
    )

    config = ConfigurationBuilderFactory.newConfigurationBuilder

    # Category is from ThreadContext, not %c{1}
    pattern = '%d{ABSOLUTE} %-5p [%X{category}] %m%n'
    layout = config.newLayout('PatternLayout').addAttribute('pattern', pattern)

    console = config.newAppender('stdout', 'CONSOLE').add(layout)
    config.add(console)

    root = config.newRootLogger(Level::INFO).add(config.newAppenderRef('stdout'))
    config.add(root)

    ctx = Configurator.initialize(config.build)
    ctx.updateLoggers

    @log4j2_initialized = true
  end

  def derive_category(receiver, callsite)
    if receiver.is_a?(Module)
      receiver.name.to_s
    elsif receiver.respond_to?(:class) && receiver.class.respond_to?(:name)
      receiver.class.name.to_s
    else
      UNKNOWN_CATEGORY
    end.tap do |cat|
      return cat unless cat.empty?
    end

    File.basename(callsite.path.to_s)
  end

  class Proxy
    # Common Ruby Logger API plus the level methods most people use.
    # You can add more here if you rely on additional Logger methods.
    PROXY_METHODS = (
      %i[
        trace debug info warn error fatal unknown
        add << log
        level level=
        progname progname=
        formatter formatter=
        datetime_format datetime_format=
        close
      ]
    ).freeze

    PROXY_METHODS.each do |meth|
      define_method(meth) do |*args, &block|
        receiver = Thread.current[:logging_receiver]
        callsite = Thread.current[:logging_callsite] || caller_locations(2, 1).first
        category = Logging.derive_category(receiver, callsite)

        Logging.with_category(category) do
          Logging.dispatch(__method__, *args, &block)
        end
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      Logging.backend.respond_to?(method_name, include_private) || super
    end

    # Fallback: if some library calls an unexpected method on logger,
    # try forwarding it through the same category/callsite path.
    def method_missing(method_name, *args, &block)
      return super unless Logging.backend.respond_to?(method_name)

      receiver = Thread.current[:logging_receiver]
      callsite = Thread.current[:logging_callsite] || caller_locations(2, 1).first
      category = Logging.derive_category(receiver, callsite)

      Logging.with_category(category) do
        Logging.dispatch(method_name, *args, &block)
      end
    end
  end

  def dispatch(level, *args, &block)
    if jruby?
      backend.public_send(level, *args, &block)
    else
      # Ruby Logger uses different method names for some severities
      case level
      when :fatal then backend.fatal(*args, &block)
      when :warn  then backend.warn(*args, &block)
      else
        backend.public_send(level, *args, &block)
      end
    end
  end

  def with_category(category)
    if jruby?
      prev = ThreadContext.get('category')

      begin
        ThreadContext.put('category', category)
        yield
      ensure
        if prev.nil?
          ThreadContext.remove('category')
        else
          ThreadContext.put('category', prev)
        end
      end
    else
      prev = Thread.current[:logging_category]

      begin
        Thread.current[:logging_category] = category
        yield
      ensure
        Thread.current[:logging_category] = prev
      end
    end
  end

  NUMERIC_TO_SYMBOL = {
    5 => :off,
    4 => :fatal,
    3 => :error,
    2 => :warn,
    1 => :info,
    0 => :debug,
    -1 => :trace
  }.freeze

  SYMBOL_TO_RUBY = {
    off:   Logger::FATAL, # Ruby Logger has no OFF; treat as highest threshold
    fatal: Logger::FATAL,
    error: Logger::ERROR,
    warn:  Logger::WARN,
    info:  Logger::INFO,
    debug: Logger::DEBUG,
    trace: Logger::DEBUG, # Ruby Logger has no TRACE; treat as DEBUG
    all:   Logger::DEBUG
  }.freeze

  def log_level
    @log_level ||= :info
  end

  def log_level=(level)
    sym = case level
    when Integer
      NUMERIC_TO_SYMBOL.fetch(level) do
        level > 5 ? :off : :all
      end
    when Symbol, String
      level.to_s.downcase.to_sym
    else
      :info
    end

    @log_level = sym
    apply_backend_level(sym)
    sym
  end

  def apply_backend_level(sym)
    if jruby?
      java_level = case sym
      when :off then Level::OFF
      when :fatal then Level::FATAL
      when :error then Level::ERROR
      when :warn then Level::WARN
      when :info then Level::INFO
      when :debug then Level::DEBUG
      when :trace then Level::TRACE
      when :all then Level::ALL
      else Level::INFO
      end

      # Single backend logger; set its level via core config
      ctx = LoggerContext.getContext(false)
      cfg = ctx.getConfiguration
      cfg.getRootLogger.setLevel(java_level)
      ctx.updateLoggers
    else
      backend.level = SYMBOL_TO_RUBY.fetch(sym, Logger::INFO)
    end
  end
end
# module Logging

# Make `log` and `logger` available everywhere, capturing receiver + callsite.
module LoggingInjection
  def logger
    Thread.current[:logging_receiver] = self
    Thread.current[:logging_callsite] = caller_locations(1, 1).first
    Logging.logger
  end
  alias log logger
end

Object.include(LoggingInjection)

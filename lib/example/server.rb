# encoding: utf-8
# frozen_string_literal: false

# -*- mode: ruby -*-
# vi: set ft=ruby :

require 'netty'

require_relative 'logging'
require_relative 'shutdown_hook'

java_import 'io.netty.bootstrap.ServerBootstrap'
java_import 'io.netty.channel.ChannelHandlerContext'
java_import 'io.netty.channel.ChannelInboundHandlerAdapter'
java_import 'io.netty.channel.ChannelInitializer'
java_import 'io.netty.channel.group.DefaultChannelGroup'
java_import 'io.netty.channel.nio.NioEventLoopGroup'
java_import 'io.netty.channel.socket.SocketChannel'
java_import 'io.netty.channel.socket.nio.NioServerSocketChannel'
java_import 'io.netty.handler.codec.LineBasedFrameDecoder'
java_import 'io.netty.handler.codec.string.StringDecoder'
java_import 'io.netty.handler.codec.string.StringEncoder'
java_import 'io.netty.util.concurrent.GlobalEventExecutor'
java_import 'io.netty.util.CharsetUtil'

class EchoHandler < ChannelInboundHandlerAdapter
  def channelRead(ctx, msg)
    # msg is a Java String because of StringDecoder
    ctx.write(msg)
  end

  def channelReadComplete(ctx)
    ctx.flush
  end

  def exceptionCaught(ctx, cause)
    cause.printStackTrace
    ctx.close
  end
end

class EchoServerInitializer < ChannelInitializer
  def initChannel(ch)
    pipeline = ch.pipeline

    # Make messages newline-delimited strings.
    pipeline.addLast(LineBasedFrameDecoder.new(8_192))
    pipeline.addLast(StringDecoder.new(CharsetUtil::UTF_8))
    pipeline.addLast(StringEncoder.new(CharsetUtil::UTF_8))

    pipeline.addLast(EchoHandler.new)
  end
end

class EchoServer
  PORT = Integer(ENV.fetch('PORT', '8007'), 10)

  def initialize
    @boss_group = NioEventLoopGroup.new(1)
    @worker_group = NioEventLoopGroup.new

    Example::ShutdownHook.new(self)
    @bootstrap = ServerBootstrap.new
      .group(@boss_group, @worker_group)
      .channel(NioServerSocketChannel.java_class)
      .childHandler(EchoServerInitializer.new)
    @channel_group ||= DefaultChannelGroup.new(
      'server_channels', GlobalEventExecutor::INSTANCE)
    @channel = nil
  end

  def run
    f = @bootstrap.bind(PORT).sync
    @channel = f.channel
    @channel_group.add(@channel)
    logger.info "Listening on #{@channel.local_address}"
    @channel.closeFuture.sync
  ensure
    stop
  end

  def shutdown
    $stdout.puts "The warnings are triggered here..."
    $stdout.flush
    @channel_group.disconnect().awaitUninterruptibly()
    @channel_group.close().awaitUninterruptibly()
    $stdout.puts "</trigger>"
    $stdout.flush
  end

  def stop
    @boss_group&.shutdownGracefully()
    @worker_group&.shutdownGracefully()
  end
end

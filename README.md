# reproducing-github-jruby-8620

```sh
mise install
bundle install
bundle exec rspec
```

Should produce:

```
nelsnelson@neptuno:~/Documents/code/reproducing-github-jruby-8620[main]$ date; bundle exec rspec
Fri Feb  6 14:46:31 CST 2026

JRuby
  when a shutdown hook thread interacts with other threads
comprehensive output:
14:46:35,750 INFO  [EchoServer] Listening on /[0:0:0:0:0:0:0:0]:8007
The warnings are triggered here...
:1: warning: already initialized constant java.lang.constant::Constable
:1: warning: already initialized constant java.lang.invoke::TypeDescriptor
:1: warning: already initialized constant java.lang.reflect::AnnotatedElement
:1: warning: already initialized constant java.lang.reflect::Type
:1: warning: already initialized constant java.lang.reflect::GenericDeclaration
:1: warning: already initialized constant java.io::Serializable
:1: warning: already initialized constant java.lang::Class
:1: warning: already initialized constant java.lang::Object
:1: warning: already initialized constant java.lang.constant::ConstantDesc
:1: warning: already initialized constant java.lang.constant::DynamicConstantDesc
:1: warning: already initialized constant java.lang::Comparable
:1: warning: already initialized constant java.lang::Enum
:1: warning: already initialized constant java.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::AbstractFuture
:1: warning: already initialized constant io.netty.util.concurrent::Promise
:1: warning: already initialized constant io.netty.util.concurrent::DefaultPromise
:1: warning: already initialized constant java.lang::Iterable
:1: warning: already initialized constant io.netty.channel.group::ChannelGroupFuture
</trigger>
-------
    emits already initialized constant warning

Finished in 2.04 seconds (files took 0.1994 seconds to load)
1 example, 0 failures

nelsnelson@neptuno:~/Documents/code/reproducing-github-jruby-8620[main]$ date; bundle exec rspec
Fri Feb  6 14:46:36 CST 2026

JRuby
  when a shutdown hook thread interacts with other threads
comprehensive output:
14:46:40,699 INFO  [EchoServer] Listening on /[0:0:0:0:0:0:0:0]:8007
14:46:40,756 INFO  [EchoServer] Shutting down
The warnings are triggered here...
:1: warning: already initialized constant java.lang.constant::Constable
:1: warning: already initialized constant java.lang.invoke::TypeDescriptor
:1: warning: already initialized constant java.lang.reflect::AnnotatedElement
:1: warning: already initialized constant java.lang.reflect::Type
:1: warning: already initialized constant java.lang.reflect::GenericDeclaration
:1: warning: already initialized constant java.io::Serializable
:1: warning: already initialized constant java.lang::Class
:1: warning: already initialized constant java.lang::Object
:1: warning: already initialized constant java.lang.constant::ConstantDesc
:1: warning: already initialized constant java.lang.constant::DynamicConstantDesc
:1: warning: already initialized constant java.lang::Comparable
:1: warning: already initialized constant java.lang::Enum
:1: warning: already initialized constant java.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::AbstractFuture
:1: warning: already initialized constant io.netty.util.concurrent::Promise
:1: warning: already initialized constant io.netty.util.concurrent::DefaultPromise
:1: warning: already initialized constant java.lang::Iterable
:1: warning: already initialized constant io.netty.channel.group::ChannelGroupFuture
</trigger>
-------
    emits already initialized constant warning

Finished in 2.04 seconds (files took 0.17524 seconds to load)
1 example, 0 failures

nelsnelson@neptuno:~/Documents/code/reproducing-github-jruby-8620[main]$ date; bundle exec rspec
Fri Feb  6 14:46:42 CST 2026

JRuby
  when a shutdown hook thread interacts with other threads
comprehensive output:
14:46:45,877 INFO  [EchoServer] Listening on /[0:0:0:0:0:0:0:0]:8007
The warnings are triggered here...
:1: warning: already initialized constant java.lang.constant::Constable
:1: warning: already initialized constant java.lang.invoke::TypeDescriptor
:1: warning: already initialized constant java.lang.reflect::AnnotatedElement
:1: warning: already initialized constant java.lang.reflect::Type
:1: warning: already initialized constant java.lang.reflect::GenericDeclaration
:1: warning: already initialized constant java.io::Serializable
:1: warning: already initialized constant java.lang::Class
:1: warning: already initialized constant java.lang::Object
:1: warning: already initialized constant java.lang.constant::ConstantDesc
:1: warning: already initialized constant java.lang.constant::DynamicConstantDesc
:1: warning: already initialized constant java.lang::Comparable
:1: warning: already initialized constant java.lang::Enum
:1: warning: already initialized constant java.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::Future
:1: warning: already initialized constant io.netty.util.concurrent::AbstractFuture
:1: warning: already initialized constant io.netty.util.concurrent::Promise
:1: warning: already initialized constant io.netty.util.concurrent::DefaultPromise
:1: warning: already initialized constant java.lang::Iterable
:1: warning: already initialized constant io.netty.channel.group::ChannelGroupFuture
</trigger>
-------
    emits already initialized constant warning

Finished in 2 seconds (files took 0.1708 seconds to load)
1 example, 0 failures
```

However, I can occasionally get the test to fail, likely implying
some sort of race condition for constant definitions in the JVM
with Ruby runtime threads.

```
nelsnelson@neptuno:~/Documents/code/reproducing-github-jruby-8620[main]$ date; bundle exec rspec
Fri Feb  6 14:46:47 CST 2026

JRuby
  when a shutdown hook thread interacts with other threads
    emits already initialized constant warning (FAILED - 1)

Failures:

  1) JRuby when a shutdown hook thread interacts with other threads emits already initialized constant warning
     Failure/Error: expect(stderr).to match(warning_pattern)
     
       expected "" to match /^:1:\s+warning:\s+already initialized constant\b/i
       Diff:
       @@ -1 +1 @@
       -/^:1:\s+warning:\s+already initialized constant\b/i
       +""
       
     # ./spec/test_spec.rb:136:in 'block in <main>'

Finished in 1.98 seconds (files took 0.17494 seconds to load)
1 example, 1 failure

Failed examples:

rspec ./spec/test_spec.rb:18 # JRuby when a shutdown hook thread interacts with other threads emits already initialized constant warning

nelsnelson@neptuno:~/Documents/code/reproducing-github-jruby-8620[main]$ 

```

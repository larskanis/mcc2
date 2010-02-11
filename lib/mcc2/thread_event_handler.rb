# -*- coding: UTF-8 -*-

require 'thread'

module Mcc2
module ThreadEventHandler
  def event_handler_pull(prd)
    prd.read(1) if prd
    while !@event_handler_events.empty?
      ev = @event_handler_events.shift
      ev.call
    end
  end
  
  def event_handler_setup
    #~ require 'socket'
    #~ gs = TCPServer.open('127.0.0.1', 0)
    #~ p gs.addr
    #~ prd = TCPSocket.open('127.0.0.1', gs.addr[1])
    #~ pwr = gs.accept

    #~ require 'socket'
    #~ s1 = UDPSocket.new
    #~ s1.bind("127.0.0.1", 0)
    #~ s2 = UDPSocket.new
    #~ s2.bind("127.0.0.1", 0)
    #~ s2.connect(*s1.addr.values_at(3,1))
    #~ s1.connect(*s2.addr.values_at(3,1))
    #~ prd, pwr = s1, s2

    if RUBY_PLATFORM =~ /win32/i
      @parent.app.addTimeout(100, :repeat => true){ event_handler_pull(nil) }
      @event_handler_pwr = nil
    else
      prd, pwr = IO.pipe
      @parent.app.addInput(prd, Fox::INPUT_READ){ event_handler_pull(prd) }
      @event_handler_pwr = pwr
    end
    @event_handler_events = Queue.new
  end
  
  def event_handler_push(&block)
    @event_handler_events << block
    @event_handler_pwr.write 'e' if @event_handler_pwr
  end
end
end

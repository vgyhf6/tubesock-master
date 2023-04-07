require 'test_helper'

# Force autoloading of classes
WebSocket::Frame::Incoming::Client
WebSocket::Frame::Outgoing::Client
WebSocket::Frame::Incoming::Server
WebSocket::Frame::Outgoing::Server

class TubesockTest < Tubesock::TestCase

  def test_raise_exception_when_hijack_is_not_available
    -> {
      Tubesock.hijack({})
    }.must_raise Tubesock::HijackNotAvailable
  end

  def test_hijack
    interaction = TestInteraction.new

    opened = MockProc.new
    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onopen(&opened)
      tubesock.onclose(&closed)

      tubesock.onmessage do |message|
        tubesock.send_data "Hello #{message}"
      end
    end

    interaction.write "Nick"
    data = interaction.read
    data.must_equal "Hello Nick"
    interaction.close

    opened.called.must_equal true
    closed.called.must_equal true
  end

  def test_close_on_close_frame
    interaction = TestInteraction.new

    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)
    end

    # That's what Firefox sends when disconnecting.
    interaction.write_raw "\x88\x82\xA3\x95\xD5\xB1\xA0|".force_encoding('binary')

    interaction.join

    closed.called.must_equal true
  end

  def test_pong_on_ping_frame
    interaction = TestInteraction.new
    interaction.tubesock {}

    # Client ping frame from: WebSocket::Frame::Outgoing::Client.new(version: 13, data: "\x1d\xcc\x18G", type: :ping).to_s
    interaction.write_raw "\x89\x84$\xBE\xDAy9r\xC2>".force_encoding('binary')

    frame = interaction.read_frame
    frame.data.must_equal "\x1d\xcc\x18G".force_encoding('binary')
    frame.type.must_equal :pong

    interaction.close
  end

  def test_onerror_callback
    interaction = TestInteraction.new

    closed = MockProc.new
    errored = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)

      tubesock.onerror(&errored)
      tubesock.onmessage do |message|
        raise "Really really really bad error"
      end
    end

    interaction.write "Hello world"
    interaction.join

    errored.called.must_equal true

  end

  def test_prevent_close_on_error
    interaction = TestInteraction.new

    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)

      tubesock.onerror do |error, message|
        tubesock.prevent_close_on_error
      end
      tubesock.onmessage do |message|
        raise "Really really really bad error"
      end
    end

    interaction.write "Hello world"
    closed.called.must_equal nil

    interaction.close
  end

  def test_default_close_on_error
    interaction = TestInteraction.new

    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)

      tubesock.onmessage do |message|
        raise "Really really really bad error"
      end
    end

    interaction.write "Hello world"
    interaction.join

    closed.called.must_equal true
  end

  def test_multi_frame_no_close
    interaction = TestInteraction.new

    closed = MockProc.new

    messaged = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)
      tubesock.onmessage(&messaged)
    end

    interaction.write "Hello world"
    sleep 1
    closed.called.must_equal nil

    interaction.close
  end

  def test_close_on_open_handler
    interaction = TestInteraction.new

    closed = MockProc.new

    interaction.tubesock do |tubesock|
      tubesock.onclose(&closed)
      tubesock.onopen do
        raise "Error opening socket"
      end
    end

    proc {interaction.join}.must_raise RuntimeError
    closed.called.must_equal true
  end

end

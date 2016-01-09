require_relative '../spec_helper'

describe "CZTop::Monitor::ZMONITOR_FPTR" do
  it "points to a dynamic library symbol" do
    assert_kind_of FFI::DynamicLibrary::Symbol, CZTop::Monitor::ZMONITOR_FPTR
  end
end

describe CZTop::Monitor do
  subject { CZTop::Monitor.new(rep_socket) }
  let(:actor) { subject.actor }
  i = 0
  let(:endpoint) { "inproc://endpoint_monitor_spec_#{i+=1}" }
  let(:req_socket) { CZTop::Socket::REQ.new(endpoint) }
  let(:rep_socket) { CZTop::Socket::REP.new(endpoint) }

  after(:each) do
    subject.terminate
  end

  it "initializes and terminates" do
    subject
  end

  describe "#initialize" do
    context "with socket" do
      it "passes socket" do
        expect(CZTop::Actor).to receive(:new)
          .with(CZTop::Monitor::ZMONITOR_FPTR, rep_socket).and_call_original
        subject
      end
    end
  end

  describe "#listen" do
    context "with one valid event" do
      let(:event) { "CONNECTED" }
      it "tells zmonitor actor" do
        expect(actor).to receive(:<<).with(["LISTEN", event])
        subject.listen(event)
      end
    end
    context "with multiple valid events" do
      let(:events) { %w[ CONNECTED DISCONNECTED ] }
      it "tells zmonitor actor" do
        expect(actor).to receive(:<<).with(["LISTEN", *events])
        subject.listen(*events)
      end
    end
    context "with invalid event" do
      let(:event) { "FOO" }
      it "raises" do
        assert_raises(CZTop::Monitor::Error) do
          subject.listen(event)
        end
      end
    end
  end

  describe "#start" do
    it "tells zmonitor to start" do
      expect(actor).to receive(:<<).with("START")
      expect(actor).to receive(:wait).at_least(2) # once for termination
      subject.start
    end
  end

  describe "#next", skip: "WIP" do # FIXME
    it "gets the next event" do
      subject.verbose!
      subject.listen(*%w[ALL])
      subject.start
      warn "started"
      Thread.new do
        req_socket << "bla"
        warn "sent to REQ"
        req_socket.disconnect(endpoint)
      end
      t = Thread.new do
        while event = subject.next
          warn "got event: #{event.inspect}"
          break if event == "DISCONNECTED"
        end
      end
      rep_socket.receive
      warn "received from REP"
      t.join
    end
  end
end

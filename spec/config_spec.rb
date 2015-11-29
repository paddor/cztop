require_relative 'spec_helper'
require 'tempfile'

describe CZTop::Config do

  context "given a config file" do
    let(:file) do
      file = Tempfile.new("zconfig_test")
      file.write <<-EOF
context
    iothreads = 1
    verbose = 1      #   Ask for a trace
main
    type = zqueue    #  ZMQ_DEVICE type
    frontend
        option
            hwm = 1000
            swap = 25000000     #  25MB
        bind = 'inproc:@@//@@addr1'
        bind = 'ipc:@@//@@addr2'
    backend
        bind = inproc:@@//@@addr3<Paste>
      EOF
      file.rewind
      return file
    end

    let(:filename) { file.path }


    describe ".load" do

      let(:loaded_config) { described_class.load(filename) }
      it "loads the file" do
        assert_kind_of described_class, loaded_config
        assert_equal filename, loaded_config.filename
      end
    end
  end
end

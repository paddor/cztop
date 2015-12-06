module CZTop
  # Represents a {CZMQ::FFI::Zmsg}.
  class Message
    # @!parse extend CZTop::FFIDelegate::ClassMethods


    include FFIDelegate

    # Coerces an object into a {Message}.
    # @param msg [Message, String, Frame]
    # @return [Message]
    # @raise [ArgumentError] if it can't be coerced
    def self.coerce(msg)
      case msg
      when Message
        return msg
      when String, Frame
        return new(msg)
      else
        raise ArgumentError, "cannot coerce message: %p" % msg
      end
    end

    # @param content [String, Frame]
    def initialize(content=nil)
      attach_ffi_delegate(CZMQ::FFI::Zmsg.new)
      self << content if content
    end

    # @return [Boolean] if this message is empty or not
    def empty?
      content_size.zero?
    end

    # Send {Message} to a {Socket} or {Actor}.
    # @param destination [Socket, Actor]
    # @note Do not use this {Message} anymore afterwards. Its native
    #   counterpart will have been destroyed.
    # @return [void]
    def send_to(destination)
      CZMQ::FFI::Zmsg.send(ffi_delegate, destination)
    end

    # Receive a {Message} from a {Socket} or {Actor}.
    # @param source [Socket, Actor]
    # @return [Message]
    def self.receive_from(source)
      from_ffi_delegate(CZMQ::FFI::Zmsg.recv(source))
    end

    # Append something to this message.
    # @param obj [String, Frame]
    # @raise [ArgumentError] if obj has an invalid type
    # @note If you provide a {Frame}, do NOT use that frame afterwards
    #   anymore, as its native counterpart will have been destroyed.
    # @return [void]
    def <<(obj)
      case obj
      when String
        ffi_delegate.addstr(obj)
      when Frame
        ffi_delegate.append(obj.ffi_delegate)
      else
        raise ArgumentError, "invalid object: %p" % obj
      end
    end

    # @return [Integer] size of this message in bytes
    # @see size
    def content_size
      ffi_delegate.content_size
    end

    # Gets the routing ID.
    # @note This only set when the frame came from a {CZTop::Socket::SERVER}
    #   socket.
    # @return [Integer] the routing ID, or 0 if unset
    ffi_delegate :routing_id

    # Sets a new routing ID.
    # @note This is used when the message is sent to a {CZTop::Socket::SERVER}
    #   socket.
    # @param new_routing_id [Integer] new routing ID
    # @raise [RangeError] if new routing ID is out of +uint32_t+ range
    # @return [new_routing_id]
    def routing_id=(new_routing_id)
      # need to raise manually, as FFI lacks this feature.
      # @see https://github.com/ffi/ffi/issues/473
      raise RangeError if new_routing_id < 0
      ffi_delegate.set_routing_id(new_routing_id)
    end
  end
end

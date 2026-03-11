# frozen_string_literal: true

module CZTop
  class Socket

    #  Socket types. Each constant in this namespace holds the type code used
    #  for the zsock_new() function.
    #
    module Types

      PAIR    = 0
      PUB     = 1
      SUB     = 2
      REQ     = 3
      REP     = 4
      DEALER  = 5
      ROUTER  = 6
      PULL    = 7
      PUSH    = 8
      XPUB    = 9
      XSUB    = 10
      STREAM  = 11

    end


    # All the available type codes, mapped to their Symbol equivalent.
    # @return [Hash<Integer, Symbol>]
    #
    TypeNames = Types.constants.to_h do |name|
      i = Types.const_get(name)
      [i, name]
    end.freeze

  end
end

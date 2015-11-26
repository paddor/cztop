module CZTop
  class Certificate
    include FFIDelegate

    def self.load(filename)
    end

    def self.new_from(public_key, secret_key)
      Zcert.new_from(public_key, secret_key)
    end

    # TODO
    def public_key_bytes
    end

    # TODO
    def secret_key_bytes
    end

    # TODO
    def public_key_txt
    end
    # TODO
    def secret_key_txt
    end

    # TODO
    def meta(key)
    end
    # TODO
    def meta=(key, value)
    end
    # TODO
    def meta_keys
    end

    # TODO
    def save(filename)
    end
    # TODO
    def save_public(filename)
    end
    # TODO
    def save_secret(filename)
    end
    # TODO
    def apply(zocket)
    end
    # TODO
    def dup
    end
    # TODO
    def ==(other)
    end
  end
end

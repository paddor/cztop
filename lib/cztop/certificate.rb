module CZTop
  class Certificate

    def self.load(filename)
    end

    def self.new_from(public_key, secret_key)
      Zcert.new_from(public_key, secret_key)
    end

    def public_key_bytes
    end

    def secret_key_bytes
    end

#    def public_key_txt
#    end
#    def secret_key_txt
#    end
    def meta(key)
    end
    def meta=(key, value)
    end
    def meta_keys
    end

    def save(filename)
    end
    def save_public(filename)
    end
    def save_secret(filename)
    end
    def apply(zocket)
    end
    def dup
    end
    def ==(other)
    end
  end
end

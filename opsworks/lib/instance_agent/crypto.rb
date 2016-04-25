# encoding: UTF-8
module InstanceAgent
  class Crypto
    @public_key_fingerprint = nil

    class << self
      attr_accessor :public_key_fingerprint
    end

    def self.instance_rsa
      OpenSSL::PKey::RSA.new(InstanceAgent::Config.config[:instance_private_key])
    end

    def self.charlie_rsa
      OpenSSL::PKey::RSA.new(InstanceAgent::Config.config[:charlie_public_key])
    end

    def self.instance_public_key_fingerprint
      return @public_key_fingerprint if @public_key_fingerprint

      # Ensure correct RSA Public Key format on Ruby 1.8.7/OpenSSL for Ruby 1.0
      public_key_der = execute_command("echo '#{instance_rsa.to_pem}' | openssl rsa -inform PEM -in /dev/stdin -outform DER -pubout 2>/dev/null")

      @public_key_fingerprint = OpenSSL::Digest::SHA1.new(public_key_der).hexdigest
      @public_key_fingerprint
    end

    def self.valid_signature?(signature, data)
      digest = OpenSSL::Digest::SHA256.new
      charlie_rsa.verify(digest, Base64.decode64(signature), data)
    end

    def self.decrypt_key(encrypted_key)
      instance_rsa.private_decrypt(Base64.decode64(encrypted_key))
    end

    def self.decrypt(key, iv, encrypted_data)
      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.decrypt
      cipher.key = key
      cipher.iv = iv
      cipher.update(encrypted_data) + cipher.final
    end

    def self.encrypt_key(key)
      Base64.encode64(charlie_rsa.public_encrypt(key))
    end

    def self.encrypt(key, iv, data)
      cipher = OpenSSL::Cipher::AES.new(128, :CBC)
      cipher.encrypt
      cipher.key = key
      cipher.iv = iv
      cipher.update(encrypted_data) + cipher.final
    end

    def self.sign(data)
      Base64.encode64(instance_rsa.sign(OpenSSL::Digest::SHA256.new, data))
    end

    protected

    def self.execute_command(command)
      `#{command}`
    end
  end
end

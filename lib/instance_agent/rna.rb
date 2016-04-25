# encoding: UTF-8
module InstanceAgent
  class Rna

    # Commands older than MAX_COMMAND_LIFETIME (seconds) will be discarded
    MAX_COMMAND_LIFETIME = 3600

    attr_reader :command_id, :command_type, :log_url, :dna_url, :sent_at, :logger, :state

    @received_command_ids = {}

    class << self
      attr_accessor :received_command_ids
    end

    def self.get(client, logger)
      response_data = client.get_command.data
      logger.debug "Response data: #{response_data.inspect}"
      if response_data && response_data["Command"]
        logger.debug "Downloaded RNA: #{response_data["Command"]}"
        new(response_data["Command"], logger).sequence
      end
    end

    def self.store_command_id(command_id, sent_at)
      InstanceAgent::Rna.cleanup_received_command_ids

      InstanceAgent::Rna.received_command_ids[command_id] = sent_at
    rescue Exception => e
      raise ::InstanceAgent::CommandStoringFailure, e.message
    end

    def self.cleanup_received_command_ids
      InstanceAgent::Rna.received_command_ids.delete_if{|id,time| time < Time.now - MAX_COMMAND_LIFETIME }
    rescue Exception => e
      raise ::InstanceAgent::CleanupExecutedCommandIdsFailure, e.message
    end


    def initialize(downloaded_rna, logger)
      @downloaded_rna = downloaded_rna
      @logger = logger
    end

    def sequence
      rna_decode
      rna_encrypted_data_verify
      rna_encrypted_data_decrypt
      rna_encrypted_data_decode
      rna_attribute_validation
      set_attributes
      rna_check_expired_command
      rna_check_duplicated_command

      InstanceAgent::Rna.store_command_id(command_id, sent_at)
      logger.info("Decoded RNA for command #{command_id}: #{command_type} sent at #{sent_at.inspect}")

      self
    end

    def rna_decode
      @decoded_rna = JSON.parse(@downloaded_rna, :symbolize_names => true)
    rescue JSON::ParserError, TypeError => e
      raise ::InstanceAgent::RNADecodingFailure, e.message
    end

    def rna_encrypted_data_verify
      if InstanceAgent::Crypto.valid_signature?(@decoded_rna[:signature], @decoded_rna[:encrypted_data])
        @verified_rna_encrypted_data = @decoded_rna[:encrypted_data]
      else
        raise ::InstanceAgent::RNAEncryptedDataVerificationFailure
      end
    end

    def rna_encrypted_data_decrypt
      key = InstanceAgent::Crypto.decrypt_key(@decoded_rna[:encrypted_key])
      iv = Base64.decode64(@decoded_rna[:iv])
      encrypted_data = Base64.decode64(@verified_rna_encrypted_data)
      @decrypted_rna_encrypted_data = InstanceAgent::Crypto.decrypt(key, iv, encrypted_data)
    rescue => e
      raise ::InstanceAgent::RNAEncryptedDataDecryptionFailure, e.message, e.backtrace
    end

    def rna_encrypted_data_decode
      @decoded_rna_encrypted_data = JSON.parse(@decrypted_rna_encrypted_data,
                                               :symbolize_names => true)
    rescue JSON::ParserError, TypeError => e
      raise ::InstanceAgent::RNAEncryptedDataDecodingFailure, e.message
    end

    def rna_attribute_validation
      [:id, :type, :dna_url, :log_url].each do |command_attribute|
        raise ::InstanceAgent::RNAAttributeMissing, "The RNA is missing #{command_attribute}" unless @decoded_rna_encrypted_data[:command].present? && @decoded_rna_encrypted_data[:command][command_attribute].present?
      end
      raise ::InstanceAgent::RNAAttributeMissing, "The RNA is missing meta sent_at" unless @decoded_rna_encrypted_data[:meta].present? && @decoded_rna_encrypted_data[:meta][:created_at].present?
    end

    def set_attributes
      @command_id = @decoded_rna_encrypted_data[:command][:id].to_s
      @command_type = @decoded_rna_encrypted_data[:command][:type].to_s
      @dna_url = @decoded_rna_encrypted_data[:command][:dna_url]
      @log_url = @decoded_rna_encrypted_data[:command][:log_url]
      @sent_at = Time.parse(@decoded_rna_encrypted_data[:meta][:created_at])
    end

    def rna_check_expired_command
      @state = "expired" if sent_at < Time.now - MAX_COMMAND_LIFETIME
    end

    def rna_check_duplicated_command
      if InstanceAgent::Rna.received_command_ids.key?(@command_id)
        raise ::InstanceAgent::RNACommandDuplicationFailure, @command_id
      end
    end

    def expired?
      state == "expired"
    end

  end
end

# encoding: UTF-8

module InstanceAgent
  module Agent
    class ProcessCommand < Base
      attr_accessor :rna

      ALLOWED_ACTIVITIES_BEFORE_SETUP = ['setup', 'update_custom_cookbooks', 'execute_recipes']
      COMMAND_FETCH_DELAY = 0.25
      COMMAND_REPORT_DELAY = 0.25

      DNA_FETCH_RETRY_COUNT = 10
      DNA_FETCH_DELAY = 2


      def perform
        self.rna = nil
        log(:info, 'Polling for command to process')

        return unless next_rna = Rna.get(client, logger)

        case next_rna.state
        when "expired"
          self.rna = next_rna
          report("expired")
          perform
        else
          process_command(next_rna)
        end

      rescue Exception => e
        log(:error, "Error during perform: #{e.class.name} - #{e.message} - #{e.backtrace.join("\n")}")
        report(e.class.name.demodulize.underscore)
      end

    protected

      def process_command(next_rna)
        case next_rna.command_type
        when "deregister"
          uninstall
        when "configure"
          configure(next_rna)
        else
          # command is not a configure, process it and continue
          execute(next_rna)
          sleep COMMAND_FETCH_DELAY
          perform
        end
      end

      def data_template(status)
        {
          :command => {
            :id => rna.try(:command_id),
            :status => status
          },
          :chef => {
            :exitcode => @runner.try(:exitcode),
            :duration => @runner.try(:duration)
          }
        }
      end

      def configure(next_rna)
        configures = [next_rna]
        following_rna = nil

        superseded_limit = InstanceAgent::Config.config.fetch(:superseded_command_limit, 20)
        (superseded_limit - 1).times do
          sleep COMMAND_FETCH_DELAY

          begin
            next_rna = Rna.get(client, logger)
          rescue Exception => e
            log(:error, "Error whilst fetching another command - #{e.class.name} - #{e.message} - #{e.backtrace.join("\n")}")
            next
          end

          break if next_rna.nil?

          if next_rna.command_type != 'configure'
            # a non configure command has appeared,
            # store it for execution after the configure
            # commands
            following_rna = next_rna
            break
          end

          configures.push(next_rna)
        end

        # isolate the most recent configure command so
        # it can be executed
        configures.sort! { |a,b| a.sent_at.to_i <=> b.sent_at.to_i }
        configure_rna = configures.pop

        superseded_ids = configures.map { |rna| rna.command_id }
        log(:info, "Command #{configure_rna.command_id} has superseded these commands: #{superseded_ids.join(', ')}") if superseded_ids.count > 0

        # mark all the other commands as superseded
        configures.each do |current_rna|
          begin
            self.rna = current_rna

            sleep COMMAND_REPORT_DELAY
            report('superseded')
          rescue Exception => e
            log(:error, "Error whilst reporting command #{current_rna.command_id rescue ''} as superseded: #{e.class.name} - #{e.message} - #{e.backtrace.join("\n")}")
          end
        end

        # execute only the last configure command
        begin
          execute(configure_rna)
        rescue Exception => e
          log(:error, "#{e.class.name} - #{e.message} - #{e.backtrace.join("\n")}")
          report(e.class.name.demodulize.underscore)
        end

        # also execute the delimiting command if
        # one was encountered
        execute(following_rna) if following_rna

        sleep COMMAND_FETCH_DELAY
        perform
      end

      def encrypt_data(status)
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        key = cipher.random_key
        iv = Base64.encode64(cipher.random_iv)
        encrypted_data = Base64.encode64(cipher.update(data_template(status).to_json) + cipher.final)

        [key, iv, encrypted_data]
      end

      def generate_message(status)
        key, iv, encrypted_data = encrypt_data(status)

        encrypted_key = Base64.encode64(
          InstanceAgent::Crypto.charlie_rsa.public_encrypt(key)
        )
        signature = InstanceAgent::Crypto.sign(encrypted_data)
        iv_signature = InstanceAgent::Crypto.sign(iv)

        {
          :type => "run_results",
          :version => "2012-10-25",
          :payload => {
            :signature => signature,
            :signature_key_id => InstanceAgent::Crypto.instance_public_key_fingerprint,
            :encrypted_key => encrypted_key,
            :iv => iv,
            :iv_signature => iv_signature,
            :encrypted_data => encrypted_data
          }
        }
      end

      def report(status)
        id = rna.command_id rescue ''
        log(:info, "[#{status}] Command \"#{id}\" for \"#{rna.command_type rescue ''}\" sent at #{rna.sent_at rescue ''} processed with exitcode #{@runner.try(:exitcode)}. (#{@runner.try(:duration)} sec)")

        message = JSON.dump(generate_message(status))

        Timeout::timeout(120) do
          client.report_command_execution(:command_execution_report => message)
        end
      rescue Exception => e
        log(:error, "Failed to report status of process_command: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}")
      end

      def steps
        [
          :dna_download,
          :dna_decode,
          :dna_encrypted_data_verify,
          :dna_iv_verify,
          :dna_encrypted_data_decrypt,
          :command_execute,
          :mark_setup_as_done,
          :log_upload,
          :success
        ]
      end

      def execute(rna)
        log(:info, 'Processing command')
        self.rna = rna

        steps.each do |step|
          begin
            log(:debug, "Executing #{step}")
            send(step)
          rescue Exception => e
            log(:error, "#{e.class.name} - #{e.message} - " +
                        "#{e.backtrace.join("\n")}")
            report(e.class.name.demodulize.underscore)
            log_upload if steps.index(step) < steps.index(:log_upload) && steps.index(step) >= steps.index(:command_execute)
            break
          end
        end
      end

      def log_upload
        @log_upload = LogUpload.new(@runner.log_file, rna.log_url)
        @log_upload.upload
      rescue Exception => e
        raise ::InstanceAgent::LogUploadingFailure, e.message
      end

      def dna_download
        log(:debug, "Trying to download DNA from #{rna.dna_url}")
        1.upto(DNA_FETCH_RETRY_COUNT) do |count|
          begin
            @downloaded_dna = RestClient.get(rna.dna_url)
            log(:debug, "Downloaded DNA from #{rna.dna_url}")
            break
          rescue Exception => e
            log(:warn, "Attempt #{count} to download the DNA failed: #{e.class.name} - #{e.message} - #{e.backtrace.join("\n")}")
            raise if count == DNA_FETCH_RETRY_COUNT
            sleep DNA_FETCH_DELAY * count
          end
        end
      rescue Exception => e
        raise ::InstanceAgent::DNADownloadingFailure, e.message
      end

      def dna_decode
        @decoded_dna = JSON.parse(@downloaded_dna, :symbolize_names => true)
      rescue JSON::ParserError, TypeError => e
        raise ::InstanceAgent::DNADecodingFailure, e.message
      end

      def dna_encrypted_data_verify
        if InstanceAgent::Crypto.valid_signature?(@decoded_dna[:signature], @decoded_dna[:encrypted_data])
          @verified_dna_encrypted_data = @decoded_dna[:encrypted_data]
        else
          raise ::InstanceAgent::DNAEncryptedDataVerificationFailure
        end
      end

      def dna_iv_verify
        unless @decoded_dna.has_key?(:iv_signature)
          raise ::InstanceAgent::DNAIVSignatureMissingFailure
        end

        if InstanceAgent::Crypto.valid_signature?(@decoded_dna[:iv_signature], @decoded_dna[:iv])
          @verified_dna_iv = @decoded_dna[:iv]
        else
          raise ::InstanceAgent::DNAIVVerificationFailure
        end
      end

      def dna_encrypted_data_decrypt
        key = InstanceAgent::Crypto.decrypt_key(@decoded_dna[:encrypted_key])
        iv = Base64.decode64(@verified_dna_iv)
        encrypted_data = Base64.decode64(@verified_dna_encrypted_data)
        @decrypted_dna_encrypted_data = InstanceAgent::Crypto.decrypt(key, iv, encrypted_data)
      rescue => e
        raise ::InstanceAgent::DNAEncryptedDataDecryptionFailure, e.message
      end

      def command_execute
        if update_agent?
          @runner = UpdateAgentRunner.new(@decrypted_dna_encrypted_data)
          @runner.run
        elsif command_allowed?
          @runner = Chef::Runner.new(@decrypted_dna_encrypted_data)
          @runner.run
        else
          log(:info, "Chef run with activity '#{activity}' requested but ignored as setup is not done yet. " +
            "Only #{ALLOWED_ACTIVITIES_BEFORE_SETUP.join(', ')} are allowed at this stage.")
        end
      rescue Exception => e
        raise ::InstanceAgent::CommandExecutionFailure, e.message
      end

      def mark_setup_as_done
        if @runner.try(:exitcode) == 0 && activity == 'setup'
          File.open(setup_done_marker_file, 'w') do |file|
          file.puts Time.now.utc.strftime('%Y-%m-%d-%H-%M-%S')
          end
        end
      rescue Exception => e
        raise ::InstanceAgent::MarkSetupAsDoneFailure, e.message
      end

      def success
        report('success')
      end

      def command_allowed?
        setup_done? || ALLOWED_ACTIVITIES_BEFORE_SETUP.include?(activity)
      end

      def setup_done?
        File.exists?(setup_done_marker_file)
      end

      def activity
        begin
          dna_json = ActiveSupport::JSON.decode(@decrypted_dna_encrypted_data)
        rescue MultiJson::LoadError
          return nil
        end

        if  dna_json.has_key?('opsworks') && dna_json['opsworks'].has_key?('activity')
          dna_json['opsworks']['activity']
        else
          nil
        end
      end

      def update_agent?
        activity == "update_agent"
      end

      def setup_done_marker_file
        InstanceAgent::Config.config[:shared_dir] + '/setup.done'
      end

      def uninstall
        log(:info, "Uninstall agent")
        `sudo #{InstanceAgent::Config.config[:root_dir]}/bin/opsworks-agent-uninstaller`
      end

    end
  end
end

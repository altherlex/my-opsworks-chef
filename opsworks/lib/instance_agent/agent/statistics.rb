# encoding: UTF-8
require 'scanf'

module InstanceAgent
  module Agent
    class Statistics < Base

      VERSION = '2012-10-25'
      REPORTING_OFFSET = (10..30).to_a.sample

      attr_reader :cpu_stats, :mem_info, :load_avg

      Struct.new('CPUStats','user', 'nice', 'system', 'idle', 'iowait', 'hi', 'si', 'steal')
      Struct.new('LoadStats', '1_min', '5_min', '15_min', 'procs')

      def initialize
        ProcessManager::Config.config[:wait_between_runs] = 0
        super
      end

      def perform
        log :info, 'Calculating system statistics.'
        duration = Benchmark.realtime do
          Timeout::timeout(120) do
            client.report_statistics(:statistics_report => JSON.dump(message))
          end
        end
        log :info, "Reported statistics. (#{duration} sec)"
        sleep_until_next_run
      end

      protected
      def sleep_until_next_run
        if Time.now.sec < REPORTING_OFFSET
          next_run_at = Time.now.change(:sec => REPORTING_OFFSET)
        else
          next_run_at = (Time.now + 1.minute).change(:sec => REPORTING_OFFSET)
        end
        sleep_duration = next_run_at - Time.now
        log :debug, "Sleeping for #{sleep_duration}s to schedule next statistics report at #{next_run_at.utc}."
        sleep sleep_duration
        log :debug, "Slept #{sleep_duration}s, reporting next statistics at #{Time.now.utc}."
      end

      def message
        cipher = OpenSSL::Cipher::AES.new(128, :CBC)
        cipher.encrypt
        key = cipher.random_key
        iv = Base64.encode64(cipher.random_iv)

        generated_stats = data
        encrypted_data = Base64.encode64(cipher.update(generated_stats) + cipher.final)

        encrypted_key = InstanceAgent::Crypto.encrypt_key(key)
        signature = InstanceAgent::Crypto.sign(encrypted_data)
        iv_signature = InstanceAgent::Crypto.sign(iv)

        log :info, "Reported statistics data: " + generated_stats

        {
          :type => 'statistics',
          :version => VERSION,
          :payload => {
            :signature => signature,
            :signature_key_id => InstanceAgent::Crypto.instance_public_key_fingerprint,
            :encrypted_key => encrypted_key,
            :iv => iv,
            :iv_signature => iv_signature,
            :encrypted_data => encrypted_data
          }
        }
      rescue Exception => e
        raise "Could not generate statistics message: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

      def calculate_cpu_stats
        # read total CPU statistics. Use 'man 5 proc' to get more details
        cpu_stats_ref = Struct::CPUStats.new(0, 0, 0, 0, 0, 0, 0, 0)
        @cpu_stats = Struct::CPUStats.new(0, 0, 0, 0, 0, 0, 0, 0)
        total = 0

        begin
          stats_ref = File.read('/proc/stat').scanf('cpu  %d %d %d %d %d %d %d %d')
          raise '/proc/stat does not have the expected format' if stats_ref.empty?

          stats_ref.each_with_index do |time, index|
            cpu_stats_ref[index] = ("%0.02f" % time).to_f
          end

          3.times do
            sleep 1
            # /proc/stat is formatted with 2 spaces after 'cpu'
            File.read('/proc/stat').scanf('cpu  %d %d %d %d %d %d %d %d').each_with_index do |time, index|
              @cpu_stats[index] = ("%0.02f" % [ time.to_f - cpu_stats_ref[index] ]).to_f
            end
          end
          total = @cpu_stats.values.inject(:+)

        rescue Exception => e
          raise "Couldn't gather cpu stats: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        end

        # add 0.2 to total, to compensate rounding. Not doing this will lead to delivering a >100% measurement
        # TODO: do the whole calculation using Fixnums and convert them only at this point to Floats. This will
        # save us the 'weird' division by "fake total"
        @cpu_stats.each_with_index do |member, index|
          @cpu_stats[index] = ("%0.02f" % [ 100 * (@cpu_stats[index] / (total.to_f + 0.2)) ]).to_f
        end
      rescue Exception => e
        raise "Couldn't calculate cpu usage metrics: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

      def calculate_mem_info
        # read total Memory usage statistics. Use 'man 5 proc' to get more details
        raise "Couldn't gather memory stats. #{e.class} - #{e.message} - #{e.backtrace.join("\n")}" unless
          @mem_info = Hash[File.read('/proc/meminfo').scan(/(\S+):\s+(\d+)/)]

        @mem_info.each_pair{ |k, v| @mem_info[k] = v.to_i }

        @mem_info.update(
          'MemUsed' => @mem_info['MemTotal'] - @mem_info['MemFree'] - @mem_info['Cached'] - @mem_info['Buffers'],
          'SwapUsed' => @mem_info['SwapTotal'] - @mem_info['SwapFree']
        )
      rescue Exception => e
        raise "Couldn't calculate memory usage metrics: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

      def calculate_load_avg
        @load_avg = Struct::LoadStats.new
        min_procs = 5
        # read Load statistics. Use 'man 5 proc' to get more details
        File.read('/proc/loadavg').split(' ').take(4).each_with_index do |avg, index|
          @load_avg[index] = avg
        end

        # we expect values found, only numeric values are acceptable
        raise 'Unexpected value found during calculation of load_avg' if @load_avg.values.map{|v| v !=~ (/^\d/) }.include?(false)

        @load_avg['procs'] = @load_avg['procs'].split('/').last.to_i
        raise "Broken measurement, the number or processes too low ( #{@load_avg['procs']} < #{min_procs} )" if @load_avg['procs'] < min_procs

        (0..2).each{ |index| @load_avg[index] = @load_avg[index].to_f }
        @load_avg
      rescue Exception => e
        raise "Couldn't report load metrics: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
      end

      def data
        calculate_cpu_stats
        calculate_mem_info
        calculate_load_avg

        @cpu_stats.each_with_index{|stat, index| stat ||= 0; @cpu_stats[index] = stat < 0.0 ? 0.0 : stat}
        @load_avg.each_with_index{|stat, index| stat ||= 0; @load_avg[index] = stat < 0.0 ? 0.0 : stat}

        @mem_info.each{|index, stat| stat ||= 0; @mem_info[index] = stat < 0 ? 0 : stat}

        statistics = {
          :stats => {
            :cpu => {
                :system => @cpu_stats['system'],
                :user => @cpu_stats['user'],
                :nice => @cpu_stats['nice'],
                :waitio => @cpu_stats['iowait'],
                :steal => @cpu_stats['steal'],
                :idle => @cpu_stats['idle']
            },
            :memory => {
                :free => @mem_info['MemFree'],
                :used => @mem_info['MemUsed'],
                :swap => @mem_info['SwapUsed'],
                :buffers => @mem_info['Buffers'],
                :cached => @mem_info['Cached'],
                :total => @mem_info['MemTotal']
            },
            :load => {
                :load_1 => @load_avg['1_min'],
                :load_5 => @load_avg['5_min'],
                :load_15 => @load_avg['15_min']
            },
            :procs => @load_avg['procs'].to_i,
            :collected_at => Time.now.utc.iso8601
          }
        }

        JSON.dump(statistics)
      rescue Exception => e
        log :error, "Error when creating statistics data: #{e.class} - #{e.message} - #{e.backtrace.join("\n")}"
        '{}'
      end

    end
  end
end

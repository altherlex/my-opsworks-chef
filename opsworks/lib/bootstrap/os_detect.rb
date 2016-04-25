module Bootstrap
  module OSDetect
    def platform
      detect_os unless @platform
      @platform
    end

    def platform_version
      detect_os unless @platform_version
      @platform_version
    end

    def platform_family
      detect_platform_family unless @platform_family
      @platform_family
    end

    def rhel_family?
      platform_family == "rhel"
    end

    def redhat?
      platform == "redhat"
    end

    def amazon_linux?
      platform == "amazon"
    end

    def debian_family?
      platform_family == "debian"
    end

    def ubuntu?
      platform == "ubuntu"
    end

    def debian?
      platform == "debian"
    end

    private

    def detect_lsb_release
      lsb_id = nil
      lsb_release = nil

      if File.exist?("/usr/bin/lsb_release") && File.executable?("/usr/bin/lsb_release")
        lsb_id = `lsb_release --short --id`.strip
        lsb_release = `lsb_release --short --release`.strip
      elsif File.exist?("/etc/lsb-release")
        read_lsb = lambda(key) do
          IO.read("/etc/lsb-release").lines.select { |line| line =~ /#{key}/ }.sub(/^#{key}=\(.*\)$/, '\1').strip
        end

        lsb_id = read_lsb.call("DISTRIB_ID")
        lsb_release = read_lsb.call("DISTRIB_RELEASE")
      end

      return lsb_id, lsb_release
    end

    def get_redhatish_platform(file)
      content = IO.read(file)
      if content =~ /Red Hat/
        "redhat"
      elsif content =~ /CentOS/
        "redhat"
      elsif content =~ /Amazon Linux/
        "amazon"
      else
        content
      end
    end

    def get_redhatish_version(file)
      content = IO.read(file)
      content.gsub(/^.*release ([0-9.]+).*$/, '\1').strip
    end

    def detect_os
      lsb_id, lsb_release = detect_lsb_release

      if File.exist? "/etc/debian_version"
        if lsb_id =~ /[Uu]buntu/
          @platform = "ubuntu"
          @platform_version = lsb_release
        else
          @platform = "debian"
          @platform_version = IO.read("/etc/debian_version")
        end
      elsif File.exist? "/etc/redhat-release"
        @platform = get_redhatish_platform("/etc/redhat-release")
        @platform_version = get_redhatish_version("/etc/redhat-release")
      elsif File.exist? "/etc/system-release"
        @platform = get_redhatish_platform("/etc/system-release")
        @platform_version = get_redhatish_version("/etc/system-release")
      else
        @platform = lsb_id
        @platform_version = lsb_release
      end
    end

    def detect_platform_family
      detect_os unless @platform
      case @platform
      when "debian", "ubuntu"
        @platform_family = "debian"
      when "centos", "redhat", "amazon"
        @platform_family = "rhel"
      else
        @platform_family = @platform
      end
    end
  end
end

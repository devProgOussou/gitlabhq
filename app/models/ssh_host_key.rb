# frozen_string_literal: true

# Detected SSH host keys are transiently stored in Redis
class SshHostKey
  class Fingerprint < Gitlab::SSHPublicKey
    attr_reader :index

    def initialize(key, index: nil)
      super(key)

      @index = index
    end

    def as_json(*)
      { bits: bits, type: type, index: index }.merge(fingerprint_data)
    end

    private

    def fingerprint_data
      data = { fingerprint_sha256: fingerprint_sha256 }
      data[:fingerprint] = fingerprint unless Gitlab::FIPS.enabled?
      data
    end
  end

  include ReactiveCaching

  self.reactive_cache_key = ->(key) { [key.class.to_s, key.id] }

  # Do not refresh the data in the background - it is not expected to change.
  # This is achieved by making the lifetime shorter than the refresh interval.
  self.reactive_cache_refresh_interval = 15.minutes
  self.reactive_cache_lifetime = 10.minutes
  self.reactive_cache_work_type = :external_dependency

  def self.find_by(opts = {})
    opts = HashWithIndifferentAccess.new(opts)
    return unless opts.key?(:id)

    project_id, url = opts[:id].split(':', 2)
    project = Project.find_by(id: project_id)

    project.presence && new(project: project, url: url)
  end

  def self.fingerprint_host_keys(data)
    return [] unless data.is_a?(String)

    data
      .each_line
      .each_with_index
      .map { |line, index| Fingerprint.new(line, index: index) }
      .select(&:valid?)
  end

  attr_reader :project, :url, :ip, :compare_host_keys

  def initialize(project:, url:, compare_host_keys: nil)
    @project = project
    @url, @ip = normalize_url(url)
    @compare_host_keys = compare_host_keys
  end

  # Needed for reactive caching
  def self.primary_key
    :id
  end

  def id
    [project.id, url].join(':')
  end

  def as_json(*)
    {
      host_keys_changed: host_keys_changed?,
      fingerprints: fingerprints,
      known_hosts: known_hosts
    }
  end

  def known_hosts
    with_reactive_cache { |data| data[:known_hosts] }
  end

  def fingerprints
    @fingerprints ||= self.class.fingerprint_host_keys(known_hosts)
  end

  # Returns true if the known_hosts data differs from the version passed in at
  # initialization as `compare_host_keys`. Comments, ordering, etc, is ignored
  def host_keys_changed?
    cleanup(known_hosts) != cleanup(compare_host_keys)
  end

  def error
    with_reactive_cache { |data| data[:error] }
  end

  def calculate_reactive_cache
    input = [ip, url.hostname].compact.join(' ')

    known_hosts, errors, status =
      Open3.popen3({}, *%W[ssh-keyscan -T 5 -p #{url.port} -f-]) do |stdin, stdout, stderr, wait_thr|
        stdin.puts(input)
        stdin.close

        [
          cleanup(stdout.read),
          cleanup(stderr.read),
          wait_thr.value
        ]
      end

    # ssh-keyscan returns an exit code 0 in several error conditions, such as an
    # unknown hostname, so check both STDERR and the exit code
    if status.success? && !errors.present?
      { known_hosts: known_hosts }
    else
      Gitlab::AppLogger.debug("Failed to detect SSH host keys for #{id}: #{errors}")

      { error: 'Failed to detect SSH host keys' }
    end
  end

  private

  # Remove comments and duplicate entries
  def cleanup(data)
    data
      .to_s
      .each_line
      .reject { |line| line.start_with?('#') || line.chomp.empty? }
      .uniq
      .sort
      .join
  end

  def normalize_url(url)
    url, real_hostname = Gitlab::HTTP_V2::UrlBlocker.validate!(
      url,
      schemes: %w[ssh],
      allow_localhost: allow_local_requests?,
      allow_local_network: allow_local_requests?,
      dns_rebind_protection: Gitlab::CurrentSettings.dns_rebinding_protection_enabled?,
      deny_all_requests_except_allowed: Gitlab::CurrentSettings.deny_all_requests_except_allowed?
    )

    # When DNS rebinding protection is required, the hostname is replaced by the
    # resolved IP. However, `url` is used in `id`, so we can't change it. Track
    # the resolved IP separately instead.
    if real_hostname
      ip = url.hostname
      url.hostname = real_hostname
    end

    # Ensure ssh://foo and ssh://foo:22 share the same cache
    url.port = url.inferred_port

    [url, ip]
  rescue Gitlab::HTTP_V2::UrlBlocker::BlockedUrlError
    raise ArgumentError, "Invalid URL"
  end

  def allow_local_requests?
    Gitlab::CurrentSettings.allow_local_requests_from_web_hooks_and_services?
  end
end

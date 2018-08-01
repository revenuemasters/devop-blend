require 'aws-sdk'
require 'active_support/inflector'
require 'cfndsl'
require 'diffy'
require 'digest/md5'

class CloudformationStack

  class << self

    def instance(name, options = {})
      self.new(name, options).create_or_update
    end

    def policy_file
      File.dirname(__FILE__) + '/stacks/' + self.template_name + '_policy.json'
    end

    def template_name
      ActiveSupport::Inflector.underscore(self.name)
    end

    def template_file
      File.dirname(__FILE__) + '/templates/' + self.template_name + '.rb'
    end

    def s3_client(options)
      @s3_client ||= Aws::S3::Client.new(
        credentials: Aws::SharedCredentials.new(profile_name: options['profile']),
        region: options['region']
      )
    end

    def get_secret(env, key, options)
      resp = s3_client(options).get_object(bucket: S3Bucket.secrets_bucket_name(env, options['aws_acnt_name']), key: key)
      resp.body.read
    rescue Aws::S3::Errors::NoSuchKey
      puts "ERROR: No secret found at key: '#{key}'"
      exit 1
    end

  end

  def initialize(name, options)
    @env       = options[:EnvName] || 'dev'
    @name      = name
    @options   = options
    @creds     = Aws::SharedCredentials.new(profile_name: options['profile'])
    @cf        = Aws::CloudFormation::Client.new(credentials: @creds, region: options['region'])
    @s3        = Aws::S3::Client.new(credentials: @creds, region: options['region'])
    @co_name   = options.fetch('co-name', 'company')
    @aws_acnt_name   = options.fetch('aws_acnt_name', 'company')
    @repo_org  = options.fetch('repo-org', @co_name)
    @repo_base = options.fetch('repo-base', "git@github.com:#{@repo_org}")
  end

  def local_template
    vars = []

    if @options['env']
      vars << [:raw, "env='#{@options[:env]}'"]
    end

    if @co_name && @repo_base
      vars << [:raw, "co_name='#{@co_name}'"]
      vars << [:raw, "repo_base='#{@repo_base}'"]
      vars << [:raw, "repo_org='#{@repo_org}'"]
    end

    if @options['config']
      # plug mailer into the config block to have it available to chef recipes without plumbing new
      # variables through the stack. use an ||= to allow a localized override per environment
      @options['config']['mailer'] ||= @options['mailer']

      # These nested JSON operations exist because of changes made to cfndsl after the pattern of using :raw was established.
      # Cfndsl now splits the raw string on '=' and splats the result as arguments (https://github.com/cfndsl/cfndsl/blob/v0.11.6/lib/cfndsl.rb#L80).
      # The config hash renders into a string with many '=>' characters, which the split processes into hundreds of arguments.
      # This causes an error because only two arguments are expected. Converting the hash to JSON avoids this because the JSON
      # string representation doesn't contain any '=' characters. Embedding "JSON.parse()" directly in the string ensures the config
      # hash is re-converted to ruby a couple lines later when the string is eval'd: https://github.com/cfndsl/cfndsl/blob/v0.11.6/lib/cfndsl.rb#L83
      # This is a workaround. Ideally either cfndsl would engineer support for a better way to split these raw extras or converge would
      # change to not depend on passing hashes of config in this way.
      vars << [:raw, "config=JSON.parse('#{@options['config'].to_json}')"]
    end

    if @options['availability-zones']
      # availability-zones: a,b,c
      azs = @options['availability-zones'].split(',')
      az_string = azs.map { |az| "'#{az}'" }.join(',')
      vars << [:raw, "availability_zones=[#{az_string}]"]
    end

    if @options['default-availability-zone']
      vars << [:raw, "default_az='#{@options['default-availability-zone']}'"]
    end

    if @options['whitelisted-ip-cidrs']
      vars << [:raw, "whitelisted_ip_cidrs=JSON.parse('#{@options['whitelisted-ip-cidrs'].to_json}')"]
    end

    # The log_groups array is defined here because it needs to be accessible both in the root of the template
    # and also inside the ASG definitions. Even global vars defined within the template weren't accessible
    # in the ASG definitions.
    vars << [:raw, "log_groups=[]"]

    JSON.pretty_generate(JSON.parse(
                          CfnDsl::eval_file_with_extras(
                            self.class.template_file, vars
                          ).to_json))
  end

  def local_policy
    begin
      File.read(self.class.policy_file)
    rescue Errno::ENOENT # Policy does not exist.
      nil
    end
  end

  def log(msg)
    puts "#{DateTime.now}: #{@name}: #{msg}"
    $stdout.flush
  end

  def while_timing_and_logging(action, &block)
    start_time = Time.now
    log "#{action}..."
    yield
    sleep_while_in_progress
    msg = "#{action} completed in #{humanize(Time.now - start_time)}"
    msg << " with status '#{status}'" if status
    log msg
  end

  def find_or_create_cfn_template_bucket
    bucket_name = "#{@aws_acnt_name}-#{@env}-templates"
    begin
      @s3.head_bucket(bucket: bucket_name)
    rescue Aws::S3::Errors::NotFound
      @bucket = @s3.create_bucket(
        acl: 'private',
        bucket: bucket_name
      )
    end
    bucket_name
  end

  def find_or_create_cfn_stack_policy_url(policy_text)
    key = "#{self.class.template_name}/#{Digest::MD5.hexdigest(policy_text)}.json"
    bucket = find_or_create_cfn_template_bucket
    begin
      @s3.head_object(bucket: bucket, key: key)
    rescue Aws::S3::Errors::NotFound
      puts policy_text
      @s3.put_object(
        acl: 'private',
        body: policy_text,
        bucket: bucket,
        key: key
      )
    end
    "https://s3.amazonaws.com/#{bucket}/#{key}"
  end

  def find_or_create_cfn_template_url(template_text)
    key = "#{self.class.template_name}/#{Digest::MD5.hexdigest(template_text)}.json"
    bucket = find_or_create_cfn_template_bucket
    begin
      @s3.head_object(bucket: bucket, key: key)
    rescue Aws::S3::Errors::NotFound
      @s3.put_object(
        acl: 'private',
        body: template_text,
        bucket: bucket,
        key: key
      )
    end
    "https://s3.amazonaws.com/#{bucket}/#{key}"
  end

  def create_or_update(params = nil)
    m = metadata

    unless m
      template_url = find_or_create_cfn_template_url(self.local_template)
      stack = {
        capabilities: ['CAPABILITY_IAM'],
        disable_rollback: true,
        parameters: hash_to_params(params),
        stack_name: @name,
        template_url: template_url
      }
      if self.local_policy
        policy_url = find_or_create_cfn_stack_policy_url(self.local_policy)
        stack[:stack_policy_url] = policy_url
      end
      while_timing_and_logging(:CREATE) do
        @cf.create_stack(stack)
      end
      m = metadata
    end

    param_changes    = stack_params_changed?(params, m.parameters)
    template_changes = stack_template_changed?(self.local_template, template)
    policy_changes   = stack_policy_changed?(self.local_policy, policy)

    if param_changes || template_changes || policy_changes
      log "changes detected!"

      if param_changes
        log "Parameter Changes:"
        puts param_changes
        $stdout.flush
      end

      if template_changes
        log "Template Changes:"
        puts template_changes
        $stdout.flush
      end

      while_timing_and_logging(:UPDATE) do
        template_url = find_or_create_cfn_template_url(self.local_template)
        stack = {
          capabilities: m.capabilities,
          notification_arns: m.notification_arns,
          parameters: hash_to_params(params),
          stack_name: @name,
          template_url: template_url
        }
        if self.local_policy
          policy_url = find_or_create_cfn_stack_policy_url(self.local_policy)
          stack[:stack_policy_url] = policy_url
        end
        begin
          @cf.update_stack(stack)
        rescue Aws::CloudFormation::Errors::ValidationError => e
          no_updates = 'No updates are to be performed'
          if e.message =~ /#{no_updates}/
            puts no_updates
            $stdout.flush
          else
            raise e
          end
        end
      end
    end

    self
  end

  def stack_params_changed?(new_params, stack_params)
    new_hash = normalize_params(new_params)
    old_hash = params_to_hash(stack_params)

    if new_hash == old_hash
      false
    else
      Diffy::Diff.new(to_sorted_yaml(old_hash), to_sorted_yaml(new_hash), :context => 3)
    end
  end

  def stack_policy_changed?(new_policy, stack_policy)
    new_policy = new_policy.nil? ? '{}' : new_policy
    stack_policy = stack_policy.nil? ? '{}' : stack_policy
    if JSON.parse(new_policy) == JSON.parse(stack_policy)
      false
    else
      Diffy::Diff.new(stack_policy, new_policy, :context => 10)
    end
  end

  def stack_template_changed?(new_template, stack_template)
    if JSON.parse(new_template) == JSON.parse(stack_template)
      false
    else
      Diffy::Diff.new(stack_template, new_template, :context => 10)
    end
  end

  def destroy
    if metadata
      while_timing_and_logging(:DELETE) do
        @cf.delete_stack(stack_name: @name)
      end
    end
  end

  def policy
    @cf.get_stack_policy(stack_name: @name).stack_policy_body
  end

  def sleep_while_in_progress
    while status =~ /IN_PROGRESS/
      sleep 3
    end
  end

  def status
    m = metadata
    m ? m.stack_status : nil
  end

  def template
    @cf.get_template(stack_name: @name).template_body
  rescue
    nil
  end

  def metadata
    @cf.describe_stacks(stack_name: @name).stacks.first
  rescue
    nil
  end

  def outputs
    return @outputs if defined? @outputs
    m = metadata
    @outputs = {}
    m.outputs.each do |output|
      @outputs[output.output_key] = output.output_value
    end if m
    @outputs
  end

  private

  def to_sorted_yaml(hash)
    convert_hash_to_ordered_hash_and_sort(hash, true).to_yaml
  rescue
    {}.to_yaml
  end

  def normalize_params(params)
    result = {}
    params.each do |k, v|
      result[k.to_s] = hide_no_echo_params(k, v)
    end
    result
  end

  def hide_no_echo_params(k, v)
    k =~ /noecho/i ? '****' : v.to_s
  end

  def hash_to_params(params_hash)
    result = []
    params_hash.each do |k, v|
      result << {
        parameter_key: k,
        parameter_value: v.to_s
      }
    end
    result
  end

  def params_to_hash(params_stack)
    result = {}
    params_stack.each do |p|
      result[p.parameter_key] = p.parameter_value
    end
    result
  end

  def humanize(secs)
    [[60, :seconds], [60, :minutes], [24, :hours], [1000, :days]].inject([]){ |s, (count, name)|
      if secs > 0
        secs, n = secs.divmod(count)
        s.unshift "#{n.to_i} #{name}"
      end
      s
    }.join(', ')
  end

  def returning(value)
    yield(value)
    value
  end

  def convert_hash_to_ordered_hash_and_sort(object, deep = false)
    # from http://seb.box.re/2010/1/15/deep-hash-ordering-with-ruby-1-8/
    if object.is_a?(Hash)
      # Hash is ordered in Ruby 1.9!
      # we are using greater than Ruby 1.9
      res = returning(Hash.new) do |map|
        object.each {|k, v| map[k] = deep ? convert_hash_to_ordered_hash_and_sort(v, deep) : v }
      end
      return res.class[res.sort {|a, b| a[0].to_s <=> b[0].to_s } ]
    elsif deep && object.is_a?(Array)
      array = Array.new
      object.each_with_index {|v, i| array[i] = convert_hash_to_ordered_hash_and_sort(v, deep) }
      return array
    else
      return object
    end
  end

end

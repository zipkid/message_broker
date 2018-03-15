require 'message_broker/version'
require 'logger'
require 'yaml'

trap 'SIGINT' do
  puts ''
  puts 'Exiting'
  exit 130
end

# Messagebroker base class
# handles stuff...
class MessageBroker
  attr_reader :plugin_config, :plugin_files, :plugins

  def initialize(options)
    @log = options[:log] || Logger.new(STDERR)
    @config = options.fetch(:config)
    @config_dir = options.fetch(:config_dir)
    @plugin_dir = @config[:plugin_dir] || File.expand_path('../message_broker/plugins', __FILE__)
    @plugin_files = []
    @plugins = {}
    @plugin_config = {}
    @log.debug('MessageBroker object initialized')
  end

  def run
    @log.debug('Starting MessageBroker run')

    require_plugins
    read_plugin_config
    create_plugin_instances
    start_plugins
    main_loop
  end

  def require_plugins
    @log.debug("Finding plugins in #{@plugin_dir}/*.rb")
    $LOAD_PATH.unshift @plugin_dir
    Dir["#{@plugin_dir}/*.rb"].each do |file|
      klass = File.basename(file, '.rb')
      @log.debug("Requiring #{klass}")
      require klass
      @plugin_files << klass
    end
  end

  def load_yaml(file)
    plugin_conf = YAML.load_file File.join(file) if File.exist?(file)
    plugin_conf || {}
  end

  def read_plugin_config
    @log.debug("Finding plugin config files in #{@config_dir}/plugins/*.yaml")
    @plugin_files.each do |file_basename|
      @log.debug("file_basename : #{file_basename}")
      # file_basename = File.basename(f, '.rb')
      @log.debug("Loading config file : #{@config_dir}/plugins/#{file_basename}.yaml")
      plugin_conf = load_yaml "#{@config_dir}/plugins/#{file_basename}.yaml"
      class_name = file_basename.split('_').collect(&:capitalize).join
      @log.debug("Config '#{class_name}' for plugin '#{file_basename}' : #{plugin_conf}")
      @plugin_config[class_name] = plugin_conf
    end
  end

  def create_plugin_instances
    @log.debug('Instantiating plugin instances')
    @plugin_config.each do |class_name, config|
      next unless config[:active]
      config[:instances].each_with_index do |plugin_conf, index|
        plugin_conf[:name] ||= "#{class_name}_#{index}"
        @log.debug("Instantiating plugin instance: #{plugin_conf[:name]}")
        plugin_conf[:log] = @log
        @plugins[plugin_conf[:name]] = Object.const_get(class_name).new(plugin_conf)
      end
    end
  end

  def start_plugins
    @log.debug('Starting plugins')
    @plugins.each do |instance_name, object|
      @log.debug("Starting plugin instance: #{instance_name}")
      object.start
    end
  end

  def collect_messages
    queue = []
    @plugins.each do |instance_name, obj|
      q = obj.read
      next if q.nil?
      q.each do |message|
        message['sending_instance_name'] = instance_name
        queue << message
      end
    end
    queue
  end

  def distribute_messages(queue)
    queue.each do |message|
      route_message message
    end
    queue.clear
  end

  def route_message(message)
    send = true
    @plugins.each do |instance_name, obj|
      message.key?('channel_name') && @plugins.key?(message['channel_name']) &&
        send = message['channel_name'] == instance_name
      send = message['sending_instance_name'] != instance_name
      obj.write message if send
    end
  end

  def main_loop
    loop do
      distribute_messages collect_messages
      sleep 0.2
    end
  end
end

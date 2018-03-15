require 'message_broker/tools'
require 'message_handler'

require 'logger'
require 'slack/rtmapi2'

#
# Slack
#
class Slack
  def initialize(options)
    @log = options[:log] || Logger.new(STDERR)
    @log.debug('Slack object initializing')
    @name = options[:name]
    @token = options.fetch(:token)
    @channels = options[:channels] || []
    @slack_rtm = Slack::RtmApi2.new(token: @token)
    @read_queue = []
    @write_queue = []
    @log.debug('Slack object initialized')
  end

  def to_s
    @name
  end

  def start
    @log.debug('Slack object starting')
    @slack_rtm.start_rtm
    @log.debug('Slack start_rtm started')
    @rtm_state_data = @slack_rtm.rtm_state_data
    create_handlers
    write_loop
    Thread.new do
      @slack_rtm.client.main_loop
    end
    @log.debug('Slack object started')

    # puts SlackWebAPI.call(
    #   token: 'xoxp-',
    #   method: 'chat.postMessage',
    #   channel: channel_id('testing'),
    #   text: 'Default text',
    #   attachments: [{
    #     fallback: "Required plain-text summary of the attachment.",
    #
    #     color: "#36a64f",
    #
    #     pretext: "Optional text that appears above the attachment block",
    #
    #     author_name: "Bobby Tables",
    #     author_link: "http://flickr.com/bobby/",
    #     author_icon: "http://flickr.com/icons/bobby.jpg",
    #
    #     title: "Slack API Documentation",
    #     title_link: "https://api.slack.com/",
    #
    #     text: "Optional text that appears within the attachment",
    #
    #     fields: [
    #       {
    #         title: "Priority",
    #         value: "High",
    #         short: false
    #       }
    #     ]
    #   }]
    # )
  end

  def read
    queue = deep_copy @read_queue
    @read_queue.clear
    queue
  end

  def write(data)
    @write_queue << data
    @log.debug("Slack instance #{@name} got :#{data}:")
  end

  private

  def create_handlers
    %w[open error message close].each { |event| send "#{event}_handler".to_sym }
    @log.debug('Slack handlers created')
  end

  def open_handler
    @slack_rtm.client.on(:open) do
      @log.debug('Slack Socket opened')
    end
  end

  def error_handler
    @slack_rtm.client.on(:error) do |message|
      # p message
      @log.error("Slack Socket error received: #{message}")
    end
  end

  def message_handler
    @slack_rtm.client.on(:message) do |data|
      data['channel_name'] = channel_data(data['channel'], 'name') if data.key? 'channel'
      data['im_name'] = im_data(data['channel'], 'name') unless data['channel_name']
      data['user_name'] = user_data(data['user'], 'name') if data.key? 'user'
      @log.debug("Slack received data: #{data}")
      if data['type'] == 'message'
        if (data.key? 'text') && (data['text'] =~ /^(dump|log)[\s_]rtm[\s_]state[\s_]data$/)
          @log.debug(@rtm_state_data) if Regexp.last_match(1) == 'log'
          pp @rtm_state_data if Regexp.last_match(1) == 'dump'
        else
          @read_queue << data
        end
      end
    end
  end

  def close_handler
    @slack_rtm.client.on(:close) do |code, reason|
      @log.debug("Slack Socket closed. Code: #{code} Reason: #{reason}")
    end
  end

  def write_loop
    sleep 5 # give time to connect to Slack
    Thread.new do
      loop do
        queue = deep_copy @write_queue
        @write_queue.clear
        queue.each do |message|
          # pp message
          MessageHandler.handle! 'slack', message
          @log.debug("Message text length: #{message['text'].length}")
          message_size = message['text'].length
          # 4000 character limit!!!
          if message_size >= 4000
            # MessageHandler.split! 4000, "\n", message
            txt = "Message text size too large for 1 post (max 4000) : #{message['text'].length}"
            @log.debug(txt)
            message['text'] = txt
          end
          if message.key? 'channel'
            @slack_rtm.client.send(type: 'message', channel: message['channel'], text: message['text'])
          else
            @channels.each do |channel|
              channel_id = channel_id(channel)

              @slack_rtm.client.send(type: 'message', channel: channel_id, text: message['text'])
            end
          end
        end
        sleep 0.2
      end
    end
  end

  def channels
    @rtm_state_data['channels']
  end

  def users
    @rtm_state_data['users']
  end

  def ims
    @rtm_state_data['ims']
  end

  def channel_id(channel_name)
    data = channels.find { |channel| channel['name'] == channel_name }
    data['id'] unless data.nil?
  end

  def channel_data(channel_id, field)
    data = channels.find { |channel| channel['id'] == channel_id }
    data[field] unless data.nil?
  end

  def user_id(user_name)
    data = users.find { |user| user['name'] == user_name }
    data['id'] unless data.nil?
  end

  def user_data(user_id, field)
    data = users.find { |user| user['id'] == user_id }
    data[field] unless data.nil?
  end

  def im_id(user_name)
    data = ims.find { |im| im['user'] == user_id(user_name) }
    data['id'] unless data.nil?
  end

  def im_data(im_id, field)
    data = ims.find { |im| im['id'] == im_id }
    return if data.nil?
    if field == 'name'
      user_data(data['user'], 'name')
    else
      data[field]
    end
  end
end

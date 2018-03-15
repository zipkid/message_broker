require 'message_broker/tools'
require 'logger'
require 'pp'

Thread.abort_on_exception = true

#
# VRTMess
#
class Vrtmess
  def initialize(options)
    @log = options[:log] || Logger.new(STDERR)
    @log.debug('VRTMess object initializing')
    @name = options[:name]
    @url = options[:url] || ''
    @read_queue = []
    @write_queue = []
    @log.debug('VRTMess object initialized')
  end

  def to_s
    @name
  end

  def start
    @log.debug('VRTMess object started')
    write_loop
  end

  def read
    queue = deep_copy @read_queue
    @read_queue.clear
    queue
  end

  def write(data)
    @write_queue << data
    @log.debug("VRTMess instance #{@name}: Got :#{data}:")
  end

  private

  def write_loop
    Thread.new do
      loop do
        queue = deep_copy @write_queue
        @write_queue.clear
        queue.each do |message|
          @log.debug("VRTMess instance #{@name}: Handle :#{message}:")
          handle(message)
        end
        sleep 0.2
      end
    end
  end

  def handle(message)
    @log.debug("VRTMess instance #{@name}: Got a question: #{message['text']}")
    # getmenu message if message['text'].scan(/is het lekker/i)
    text = message['text']
    case text
    when 'h:', 'help:'
      method_help message
    when /is het lekker/i
      getmenu message
    end
  end

  def method_help(message)
    reply = deep_copy message
    reply['text'] = %(VRT Mess
Known commands:
h: help: this

is het lekker?
Get the mess menu
)
    @read_queue << reply
    false
  end

  def getmenu(message)
    reply = deep_copy message
    reply['text'] = 'Let me see....'
    @read_queue << reply
    # false

    # Get @url
    require 'open-uri'
    file = open(@url)
    contents = file.read
    # @log.debug(contents)

    # @menu = []
    menutype = false
    contents.each_line do |line|
      line.strip!
      if /\/img\/fancy\/(.+).png/.match(line)
        menutype = Regexp.last_match(1)
        @log.debug("Type : #{menutype}.")
        next
      end
      if menutype
        @log.debug("Type : #{menutype} = #{line}")

        if line != '</div>'
          reply = deep_copy message
          reply['text'] = "#{menutype} - #{line}"
          @read_queue << reply
        end
        menutype = false
      end
      if /Geen menu gevonden :\(/.match(line)
        reply = deep_copy message
        reply['text'] = 'Geen menu gevonden :('
        @read_queue << reply
      end
      # parse line unless (line.empty?)
    end
  end
end

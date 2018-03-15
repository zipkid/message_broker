# MessageHandler
module MessageHandler
  @slack_states = {
    # $SERVICESTATE$
    'OK' => ':white_check_mark:',
    'WARNING' => ':warning:',
    'UNKNOWN' => ':question:',
    'CRITICAL' => ':x:',
    # $HOSTSTATE$
    'UP' => ':white_check_mark:',
    'DOWN' => ':x:',
    'UNREACHABLE' => ':question:'
  }
  def self.handle!(type, message)
    case type
    when 'slack'
      message[:text] = "#{@slack_states[message[:state]]} #{message[:text]}" if message.key? :state
    end
  end

  # MessageHandler.split! 4000, "\n", message
  def self.split!(count, match, message); end
end

{Robot, Adapter, TextMessage, EnterMessage, LeaveMessage, CatchAllMessage} = require 'hubot'

# {Robot, Adapter, Response, TextMessage, EnterMessage, LeaveMessage} = require 'hubot'

class SkypeKitAdapter extends Adapter
  send: (user, strings...) ->
    out = ""
    out = ("#{str}\n" for str in strings)
    json = JSON.stringify
      room: user.room
      message: out.join('')
    @skype.stdin.write json + '\n'

  reply: (user, strings...) ->
    @send user, strings...

  run: ->
    self = @
    stdin = process.openStdin()
    stdout = process.stdout
    pyScriptPath = __dirname+'/skypekit.py'
    py = 'python'
    @skype = require('child_process').spawn(py, [pyScriptPath])
    @skype.stdout.on 'data', (data) =>
        decoded = JSON.parse(data.toString())

        if '_debug_log_' of decoded
            log = decoded['_debug_log_']
            data = ''
            if '_debug_data_' of decoded
                data = JSON.stringify(decoded['_debug_data_'])
            console.log "HUBOT-SKYPEKIT DEBUG: #{log} #{data}"
            return

        user = @robot.brain.userForName decoded.user
        unless user?
            id = (new Date().getTime() / 1000).toString().replace('.','')
            user = @robot.brain.userForId id
            user.name = decoded.user
        user.room = decoded.room

        return unless decoded.message
        message = new TextMessage user, decoded.message
        @receive message
    @skype.stderr.on 'data', (data) =>
        @robot.logger.error data.toString()
    @skype.on 'exit', (code) =>
        @robot.logger.error "Lost connection with Skype... Exiting"
        process.nextTick -> process.exit(1)
    @skype.on "uncaughtException", (err) =>
      @robot.logger.error "#{err}"

    process.on "uncaughtException", (err) =>
      @robot.logger.error "#{err}"

    @emit "connected"

exports.use = (robot) ->
  new SkypeKitAdapter robot

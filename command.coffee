_             = require 'lodash'
MeshbluConfig = require 'meshblu-config'
Server        = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      redisPort     : process.env.REDIS_PORT ? 6379
      redisHost     : process.env.REDIS_HOST ? 'localhost'
      mongodbUri    : process.env.MONGODB_URI
      meshbluConfig : new MeshbluConfig().toJSON()
      port          : process.env.PORT || 80
      disableLogging: process.env.DISABLE_LOGGING == "true"

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @serverOptions.mongodbUri

    server = new Server @serverOptions
    server.run (error) =>
      return @panic error if error?

      {address,port} = server.address()
      console.log "IntervalService listening on port: #{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM caught, exiting'
      server.destroy()
      process.exit 0

command = new Command()
command.run()

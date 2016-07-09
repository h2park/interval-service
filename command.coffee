_             = require 'lodash'
MeshbluConfig = require 'meshblu-config'
Server        = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      meshbluConfig:      new MeshbluConfig().toJSON()
      redisUri:           process.env.REDIS_URI
      mongodbUri:         process.env.MONGODB_URI
      port:               process.env.PORT || 80
      disableLogging:     process.env.DISABLE_LOGGING == "true"
      intervalServiceUri: process.env.INTERVAL_SERVICE_URI

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @serverOptions.mongodbUri
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: INTERVAL_SERVICE_URI') if _.isEmpty @serverOptions.intervalServiceUri

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

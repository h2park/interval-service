_              = require 'lodash'
OctobluRaven   = require 'octoblu-raven'
MeshbluConfig  = require 'meshblu-config'
FetchPublicKey = require 'fetch-meshblu-public-key'
Server         = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      meshbluConfig:      new MeshbluConfig().toJSON()
      redisUri:           process.env.REDIS_URI
      mongodbUri:         process.env.MONGODB_URI
      port:               process.env.PORT || 80
      disableLogging:     process.env.DISABLE_LOGGING == "true"
      intervalServiceUri: process.env.INTERVAL_SERVICE_URI
      publicKeyUri:       process.env.MESHBLU_PUBLIC_KEY_URI
      octobluRaven:       new OctobluRaven()

  panic: (error) =>
    console.error error.stack
    process.exit 1

  catchErrors: =>
    @serverOptions.octobluRaven.patchGlobal()

  run: =>
    @panic new Error('Missing required environment variable: MESHBLU_PUBLIC_KEY_URI') if _.isEmpty @serverOptions.publicKeyUri
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @serverOptions.mongodbUri
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: INTERVAL_SERVICE_URI') if _.isEmpty @serverOptions.intervalServiceUri

    new FetchPublicKey().fetch @serverOptions.publicKeyUri, (error, publicKey) =>
      return @panic error if error?
      @serverOptions.publicKey = publicKey
      server = new Server @serverOptions
      server.run (error) =>
        return @panic error if error?

        {address,port} = server.address()
        console.log "IntervalService listening on port: #{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM caught, exiting'
      server?.stop =>
        process.exit 0

command = new Command()
command.catchErrors()
command.run()

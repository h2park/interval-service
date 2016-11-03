_              = require 'lodash'
MeshbluConfig  = require 'meshblu-config'
FetchPublicKey = require 'fetch-meshblu-public-key'
SigtermHandler = require 'sigterm-handler'
Server         = require './src/server'

class Command
  constructor: ->
    @serverOptions =
      meshbluConfig:      new MeshbluConfig().toJSON()
      mongodbUri:         process.env.MONGODB_URI
      port:               process.env.PORT || 80
      disableLogging:     process.env.DISABLE_LOGGING == "true"
      intervalServiceUri: process.env.INTERVAL_SERVICE_URI
      publicKeyUri:       process.env.MESHBLU_PUBLIC_KEY_URI

  panic: (error) =>
    console.error error.stack
    process.exit 1

  run: =>
    @panic new Error('Missing required environment variable: MESHBLU_PUBLIC_KEY_URI') if _.isEmpty @serverOptions.publicKeyUri
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @serverOptions.mongodbUri
    @panic new Error('Missing required environment variable: INTERVAL_SERVICE_URI') if _.isEmpty @serverOptions.intervalServiceUri

    new FetchPublicKey().fetch @serverOptions.publicKeyUri, (error, publicKey) =>
      return @panic error if error?
      @serverOptions.publicKey = publicKey
      server = new Server @serverOptions
      server.run (error) =>
        return @panic error if error?

        {address,port} = server.address()
        console.log "IntervalService listening on port: #{port}"

      sigtermHandler = new SigtermHandler
      sigtermHandler.handle server.run

command = new Command()
command.run()

_              = require 'lodash'
Redis          = require 'ioredis'
MeshbluConfig  = require 'meshblu-config'
FetchPublicKey = require 'fetch-meshblu-public-key'
SigtermHandler = require 'sigterm-handler'
Server         = require './src/server'

class Command
  constructor: ->
    @intervalServiceUri = process.env.INTERVAL_SERVICE_URI
    @mongodbUri         = process.env.MONGODB_URI
    @publicKeyUri       = process.env.MESHBLU_PUBLIC_KEY_URI
    @meshbluConfig      = new MeshbluConfig().toJSON()
    @port               = process.env.PORT || 80

  panic: (error) =>
    console.error error.stack
    process.exit 1

  getPublicKey: (callback) =>
    new FetchPublicKey().fetch @publicKeyUri, callback

  run: =>
    @panic new Error('Missing required environment variable: MESHBLU_PUBLIC_KEY_URI') if _.isEmpty @publicKeyUri
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @mongodbUri
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @redisUri
    @panic new Error('Missing required environment variable: INTERVAL_SERVICE_URI') if _.isEmpty @intervalServiceUri
    @panic new Error('Missing required variable: meshbluConfig') if _.isEmpty @meshbluConfig
    @panic new Error('Missing required variable: port') if _.isEmpty @port

    @getPublicKey (error, publicKey) =>
      return @panic error if error?
      server = new Server {
        publicKey,
        @meshbluConfig,
        @port,
        @intervalServiceUri,
        @mongodbUri,
      }
      server.run (error) =>
        return @panic error if error?
        {address,port} = server.address()
        console.log "IntervalService listening on port: #{port}"
      sigtermHandler = new SigtermHandler
      sigtermHandler.register server.run

command = new Command()
command.run()

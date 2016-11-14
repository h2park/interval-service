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
      redisUri:           process.env.REDIS_URI
      publicKeyUri:       process.env.MESHBLU_PUBLIC_KEY_URI

  panic: (error) =>
    console.error error.stack
    process.exit 1

  getRedisClient: (callback) =>
    client = new Redis @redisUri, dropBufferSupport: true
    client = _.bindAll client, _.functionsIn(client)
    client.once 'error', callback
    client.on 'ready', =>
      client.on 'error', @panic
      callback null, client

  getPublicKey: (callback) =>
    new FetchPublicKey().fetch @serverOptions.publicKeyUri, callback

  run: =>
    @panic new Error('Missing required environment variable: MESHBLU_PUBLIC_KEY_URI') if _.isEmpty @serverOptions.publicKeyUri
    @panic new Error('Missing required environment variable: MONGODB_URI') if _.isEmpty @serverOptions.mongodbUri
    @panic new Error('Missing required environment variable: REDIS_URI') if _.isEmpty @serverOptions.redisUri
    @panic new Error('Missing required environment variable: INTERVAL_SERVICE_URI') if _.isEmpty @serverOptions.intervalServiceUri

    @getPublicKey (error, publicKey) =>
      return @panic error if error?
      @serverOptions.publicKey = publicKey
      @getRedisClient (error, client) =>
        return @panic error if error?
        @serverOptions.client = client
        server = new Server @serverOptions
        server.run (error) =>
          return @panic error if error?
          {address,port} = server.address()
          console.log "IntervalService listening on port: #{port}"
        sigtermHandler = new SigtermHandler
        sigtermHandler.register server.run

command = new Command()
command.run()

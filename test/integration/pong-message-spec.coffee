http          = require 'http'
request       = require 'request'
enableDestroy = require 'server-destroy'
shmock        = require '@octoblu/shmock'
Server        = require '../../src/server'

describe 'Pong Message', ->
  beforeEach (done) ->
    @meshblu = shmock 0xd00d
    enableDestroy @meshblu

    serverOptions =
      port: undefined,
      disableLogging: true
      meshbluConfig:
        hostname: 'localhost'
        port: 0xd00d
        protocol: 'http'
      mongodbUri: 'localhost'

    @server = new Server serverOptions

    @server.run =>
      @serverPort = @server.address().port
      done()

  afterEach ->
    @meshblu.destroy()
    @server.destroy()

  describe 'On POST /message', ->
    beforeEach (done) ->
      userAuth = new Buffer('some-uuid:some-token').toString 'base64'

      @authDevice = @meshblu
        .post '/authenticate'
        .set 'Authorization', "Basic #{userAuth}"
        .reply 200, uuid: 'some-uuid', token: 'some-token'

      options =
        uri: '/message'
        baseUrl: "http://localhost:#{@serverPort}"
        auth:
          username: 'some-uuid'
          password: 'some-token'
        json: true
        body:
          topic: 'pong'

      request.post options, (error, @response, @body) =>
        done error

    it 'should return a 201', ->
      expect(@response.statusCode).to.equal 201

    it 'should auth handler', ->
      @authDevice.done()
